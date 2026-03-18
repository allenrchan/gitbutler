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

#[derive(serde::Serialize)]
#[cfg_attr(feature = "export-schema", derive(schemars::JsonSchema))]
pub struct ProjectPrStatus {
    pub has_failed_prs: bool,
}

/// Check if any open PRs for the project have failed CI checks.
/// Gracefully returns false on any error (no forge, no auth, GitLab, etc.).
#[but_api]
#[instrument(err(Debug))]
pub fn check_project_pr_status(ctx: &mut but_ctx::Context) -> Result<ProjectPrStatus> {
    match check_project_pr_status_inner(ctx) {
        Ok(status) => Ok(status),
        Err(err) => {
            tracing::debug!(?err, "check_project_pr_status failed, returning false");
            Ok(ProjectPrStatus {
                has_failed_prs: false,
            })
        }
    }
}

fn check_project_pr_status_inner(ctx: &mut but_ctx::Context) -> Result<ProjectPrStatus> {
    use anyhow::Context as _;

    let base_branch = gitbutler_branch_actions::base::get_base_branch_data(ctx)?;
    let forge_repo_info = but_forge::derive_forge_repo_info(&base_branch.remote_url)
        .context("No forge could be determined for this repository branch")?;

    let storage = but_forge_storage::Controller::from_path(but_path::app_data_dir()?);
    let preferred_forge_user = ctx.legacy_project.preferred_forge_user.clone();
    let cache_config = Some(but_forge::CacheConfig::CacheWithFallback {
        max_age_seconds: 120,
    });

    let db = &mut *ctx.db.get_mut()?;

    let reviews = but_forge::list_forge_reviews_with_cache(
        preferred_forge_user.clone(),
        &forge_repo_info,
        &storage,
        db,
        cache_config.clone(),
    )?;

    tracing::debug!(
        project = %ctx.legacy_project.title,
        open_prs = reviews.len(),
        "checking PR CI status"
    );

    for review in &reviews {
        let checks_result = but_forge::ci_checks_for_ref_with_cache(
            preferred_forge_user.clone(),
            &forge_repo_info,
            &storage,
            &review.source_branch,
            db,
            cache_config.clone(),
        );

        match checks_result {
            Ok(checks) => {
                for check in &checks {
                    tracing::trace!(
                        pr = review.number,
                        branch = %review.source_branch,
                        check_name = %check.name,
                        status = ?check.status,
                        "CI check"
                    );
                }
                let has_failure = checks.iter().any(|check| matches!(
                    &check.status,
                    but_forge::CiStatus::Complete { conclusion, .. }
                        if matches!(
                            conclusion,
                            but_forge::CiConclusion::Failure
                            | but_forge::CiConclusion::TimedOut
                            | but_forge::CiConclusion::ActionRequired
                        )
                ));
                if has_failure {
                    tracing::debug!(
                        project = %ctx.legacy_project.title,
                        pr = review.number,
                        branch = %review.source_branch,
                        "found failed CI checks"
                    );
                    return Ok(ProjectPrStatus {
                        has_failed_prs: true,
                    });
                }
            }
            Err(err) => {
                tracing::debug!(
                    pr = review.number,
                    branch = %review.source_branch,
                    ?err,
                    "failed to fetch CI checks for PR"
                );
            }
        }
    }

    Ok(ProjectPrStatus {
        has_failed_prs: false,
    })
}
