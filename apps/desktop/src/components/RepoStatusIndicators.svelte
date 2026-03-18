<script lang="ts">
	import { goto } from "$app/navigation";
	import { PROJECT_STATUS_SERVICE } from "$lib/project/projectStatusService";
	import { PROJECTS_SERVICE } from "$lib/project/projectsService";
	import { projectPath } from "$lib/routes/routes.svelte";
	import { inject } from "@gitbutler/core/context";
	import { Badge, Tooltip } from "@gitbutler/ui";

	const { activeProjectId }: { activeProjectId: string } = $props();

	const projectsService = inject(PROJECTS_SERVICE);
	const projectStatusService = inject(PROJECT_STATUS_SERVICE);

	const VOWELS = new Set("aeiouAEIOU");

	function isConsonant(c: string): boolean {
		return /[a-zA-Z]/.test(c) && !VOWELS.has(c);
	}

	/**
	 * Find the consonant nearest the midpoint of a word.
	 * Syllable boundaries cluster near word midpoints, so this naturally
	 * picks the start of the second syllable in most cases.
	 *   "Basecamp" → c (mid=4), "Frontier" → t (mid=4),
	 *   "Gizmo" → m (mid=3), "Folio" → l (mid=2, searching left from 'i')
	 */
	function midConsonant(word: string): string | null {
		const mid = Math.ceil(word.length / 2);
		// Search outward from midpoint, alternating right then left
		for (let offset = 0; offset < word.length; offset++) {
			const right = mid + offset;
			if (right < word.length && isConsonant(word[right]!)) return word[right]!;
			const left = mid - offset - 1;
			if (left > 0 && isConsonant(word[left]!)) return word[left]!;
		}
		return null;
	}

	/**
	 * Generate a 2-letter abbreviation for a project name.
	 *
	 * Multi-word (space/hyphen/camelCase): first letter of each word, both uppercase.
	 *   "Frontier Commons" → FC, "GitButler" → GB
	 *
	 * Single word: first letter (uppercase) + consonant nearest the word's midpoint
	 * (lowercase). This approximates second-syllable detection.
	 *   "Basecamp" → Bc, "Frontier" → Ft, "Gizmo" → Gm, "Folio" → Fl
	 */
	function abbreviate(name: string): string {
		const trimmed = name.trim();
		if (!trimmed) return "??";

		// Split on spaces, hyphens, underscores, or camelCase boundaries
		const words = trimmed.split(/[\s\-_]+|(?<=[a-z])(?=[A-Z])/).filter(Boolean);

		if (words.length >= 2) {
			return words[0]!.charAt(0).toUpperCase() + words[1]!.charAt(0).toUpperCase();
		}

		const word = words[0]!;
		const first = word.charAt(0).toUpperCase();
		if (word.length < 2) return first;

		const second = midConsonant(word);
		if (second) return first + second.toLowerCase();

		// Fallback: use second character
		return first + word.charAt(1).toLowerCase();
	}

	/**
	 * Generate unique abbreviations for a list of project names.
	 * On collision, the later project tries other consonants from its name.
	 */
	function abbreviateAll(names: string[]): Map<string, string> {
		const result = new Map<string, string>();
		const used = new Set<string>();

		for (const name of names) {
			let abbr = abbreviate(name);
			if (used.has(abbr)) {
				const trimmed = name.trim();
				const words = trimmed.split(/[\s\-_]+|(?<=[a-z])(?=[A-Z])/).filter(Boolean);
				const word = words.length >= 2 ? words[1]! : words[0]!;
				const first = abbr.charAt(0);
				let resolved = false;
				// Try all consonants in the word
				for (let i = 1; i < word.length; i++) {
					if (isConsonant(word[i]!)) {
						const candidate = first + word[i]!.toLowerCase();
						if (!used.has(candidate) && candidate !== abbr) {
							abbr = candidate;
							resolved = true;
							break;
						}
					}
				}
				if (!resolved) {
					let n = 2;
					while (used.has(first + n)) n++;
					abbr = first + n;
				}
			}
			used.add(abbr);
			result.set(name, abbr);
		}

		return result;
	}

	const projectsQuery = $derived(projectsService.projects());
	const allProjects = $derived(projectsQuery.result.data ?? []);
	const abbreviations = $derived(abbreviateAll(allProjects.map((p) => p.title)));
</script>

{#if allProjects.length > 1}
	<div class="repo-separator"></div>
	<div class="repo-indicators">
		{#each allProjects as project (project.id)}
			{@const isActive = project.id === activeProjectId}
			{@const statusQuery = projectStatusService.checkProjectChanges(project.path, 30_000)}
			{@const status = statusQuery.response}
			{@const isLoading = statusQuery.result.isLoading}
			{@const isError = statusQuery.result.isError}
			{@const hasChanges = status?.has_changes ?? false}
			{@const changeCount = status?.change_count ?? 0}
			{@const prQuery = projectStatusService.checkProjectPrStatus(project.id, 60_000)}
			{@const prStatus = prQuery.response}
			{@const hasFailedPrs = prStatus?.has_failed_prs ?? false}
			{@const tooltipText = isLoading
				? `${project.title}: Checking...`
				: isError
					? `${project.title}: Unable to check`
					: hasFailedPrs
						? `${project.title}: PR with failed checks`
						: hasChanges
							? `${project.title}: ${changeCount} change${changeCount !== 1 ? "s" : ""}`
							: `${project.title}: Clean`}

			<Tooltip text={tooltipText}>
				<button
					class="repo-icon"
					class:has-failed-prs={hasFailedPrs}
					class:has-changes={!hasFailedPrs && hasChanges}
					class:clean={!isLoading && !isError && !hasFailedPrs && !hasChanges}
					class:neutral={isLoading || isError}
					onclick={() => goto(projectPath(project.id))}
				>
					{abbreviations.get(project.title) ?? project.title.charAt(0).toUpperCase()}
					{#if hasChanges && changeCount > 0}
						<div class="badge-container">
							<Badge style={hasFailedPrs ? "danger" : "warning"}>
								{changeCount > 99 ? "99+" : changeCount}
							</Badge>
						</div>
					{/if}
					{#if isActive}
						<div class="active-dot"></div>
					{/if}
				</button>
			</Tooltip>
		{/each}
	</div>
{/if}

<style lang="postcss">
	.repo-separator {
		width: 20px;
		height: 1px;
		background-color: var(--clr-border-2);
		margin: 4px auto;
	}

	.repo-indicators {
		display: flex;
		flex-direction: column;
		gap: 4px;
	}

	.repo-icon {
		position: relative;
		width: 34px;
		height: 34px;
		border-radius: var(--radius-ml);
		border: 2px solid transparent;
		background-color: var(--clr-bg-2);
		color: var(--clr-text-2);
		font-weight: 700;
		font-size: 11px;
		letter-spacing: -0.02em;
		cursor: pointer;
		display: flex;
		align-items: center;
		justify-content: center;
		transition:
			border-color var(--transition-fast),
			color var(--transition-fast),
			opacity var(--transition-fast);

		&:hover {
			background-color: var(--clr-bg-1);
		}

		&.has-failed-prs {
			border-color: var(--clr-theme-danger-element);
			color: var(--clr-theme-danger-element);
		}

		&.has-changes {
			border-color: var(--clr-theme-warn-element);
			color: var(--clr-theme-warn-element);
		}

		&.clean {
			border-color: var(--clr-theme-succ-element);
			opacity: 0.5;

			&:hover {
				opacity: 0.8;
			}
		}

		&.neutral {
			border-color: var(--clr-border-2);
			color: var(--clr-text-3);
			opacity: 0.5;
		}
	}

	.badge-container {
		position: absolute;
		top: -6px;
		right: -8px;
		pointer-events: none;
	}

	.active-dot {
		position: absolute;
		bottom: -4px;
		left: 50%;
		transform: translateX(-50%);
		width: 6px;
		height: 6px;
		border-radius: 50%;
		background-color: var(--clr-text-1);
		pointer-events: none;
	}
</style>
