<script lang="ts">
	import { goto } from "$app/navigation";
	import { PROJECT_STATUS_SERVICE } from "$lib/project/projectStatusService";
	import type { Project } from "$lib/project/project";
	import { PROJECTS_SERVICE } from "$lib/project/projectsService";
	import { projectPath } from "$lib/routes/routes.svelte";
	import { inject } from "@gitbutler/core/context";
	import { Badge, Tooltip } from "@gitbutler/ui";

	const { activeProjectId }: { activeProjectId: string } = $props();

	const projectsService = inject(PROJECTS_SERVICE);
	const projectStatusService = inject(PROJECT_STATUS_SERVICE);

	const projectsQuery = $derived(projectsService.projects());
	const otherProjects = $derived(
		(projectsQuery.result.data ?? []).filter((p: Project) => p.id !== activeProjectId),
	);
</script>

{#if otherProjects.length > 0}
	<div class="repo-separator"></div>
	<div class="repo-indicators">
		{#each otherProjects as project (project.id)}
			{@const statusQuery = projectStatusService.checkProjectChanges(project.path, 30_000)}
			{@const status = statusQuery.response}
			{@const isLoading = statusQuery.result.isLoading}
			{@const isError = statusQuery.result.isError}
			{@const hasChanges = status?.has_changes ?? false}
			{@const changeCount = status?.change_count ?? 0}
			{@const tooltipText = isLoading
				? `${project.title}: Checking...`
				: isError
					? `${project.title}: Unable to check`
					: hasChanges
						? `${project.title}: ${changeCount} change${changeCount !== 1 ? "s" : ""}`
						: `${project.title}: Clean`}

			<Tooltip text={tooltipText}>
				<button
					class="repo-icon"
					class:has-changes={hasChanges}
					class:clean={!isLoading && !isError && !hasChanges}
					class:neutral={isLoading || isError}
					onclick={() => goto(projectPath(project.id))}
				>
					{project.title.charAt(0).toUpperCase()}
					{#if hasChanges && changeCount > 0}
						<div class="badge-container">
							<Badge style="warning">
								{changeCount > 99 ? "99+" : changeCount}
							</Badge>
						</div>
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
		font-size: 14px;
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
</style>
