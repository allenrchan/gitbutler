import { providesItem, ReduxTag } from "$lib/state/tags";
import { InjectionToken } from "@gitbutler/core/context";
import type { BackendApi } from "$lib/state/clientState.svelte";

export type ProjectChangeStatus = {
	has_changes: boolean;
	change_count: number;
};

export type ProjectPrStatus = {
	has_failed_prs: boolean;
};

export const PROJECT_STATUS_SERVICE = new InjectionToken<ProjectStatusService>(
	"ProjectStatusService",
);

export class ProjectStatusService {
	private api: ReturnType<typeof injectEndpoints>;

	constructor(api: BackendApi) {
		this.api = injectEndpoints(api);
	}

	checkProjectChanges(path: string, pollingInterval?: number) {
		return this.api.endpoints.checkProjectChanges.useQuery(
			{ path },
			{ subscriptionOptions: { pollingInterval } },
		);
	}

	checkProjectPrStatus(projectId: string, pollingInterval?: number) {
		return this.api.endpoints.checkProjectPrStatus.useQuery(
			{ projectId },
			{ subscriptionOptions: { pollingInterval } },
		);
	}
}

function injectEndpoints(api: BackendApi) {
	return api.injectEndpoints({
		endpoints: (build) => ({
			checkProjectChanges: build.query<ProjectChangeStatus, { path: string }>({
				extraOptions: { command: "check_project_changes" },
				query: (args) => args,
				providesTags: (_result, _error, args) =>
					providesItem(ReduxTag.ProjectChangeStatus, args.path),
			}),
			checkProjectPrStatus: build.query<ProjectPrStatus, { projectId: string }>({
				extraOptions: { command: "check_project_pr_status" },
				query: (args) => args,
				providesTags: (_result, _error, args) =>
					providesItem(ReduxTag.ProjectPrStatus, args.projectId),
			}),
		}),
	});
}
