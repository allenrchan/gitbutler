use std::path::PathBuf;

use anyhow::Result;
use but_api_macros::but_api;
use tracing::instrument;

#[derive(serde::Serialize)]
#[cfg_attr(feature = "export-schema", derive(schemars::JsonSchema))]
pub struct ProjectChangeStatus {
    pub has_changes: bool,
    pub change_count: usize,
}

/// Check if a project at the given path has uncommitted worktree changes.
/// Uses fast no-rename-tracking diff for performance.
#[but_api]
#[instrument(err(Debug))]
pub fn check_project_changes(path: PathBuf) -> Result<ProjectChangeStatus> {
    let repo = gix::open(&path)?;
    let changes = but_core::diff::worktree_changes_no_renames(&repo)?;
    Ok(ProjectChangeStatus {
        has_changes: !changes.changes.is_empty(),
        change_count: changes.changes.len(),
    })
}
