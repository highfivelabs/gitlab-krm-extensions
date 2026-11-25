# gitlab-krm-extensions

Kubernetes kinds for the GitLab configuration that Terraform's
`gitlabhq/gitlab` provider manages and GitLab's operators do not. GitLab's official operators install GitLab itself (GitLab Operator) and runners (GitLab Runner Operator); none manages projects, groups or users.

By the numbers: `gitlabhq/gitlab` is the #29 Terraform provider by downloads
(206,030,762); version 19.5.0 has 142 resources. Operators
cover 0. This repository adds **141 kinds** standing in for
**142 more**. Each gap kind is listed below with its Terraform equivalent.

**Readiness: 52 of 141 kinds also proven against the real API.** Every kind passes
create, update, drift repair and delete against a fake built from the same
descriptors (`TestEveryKindOnFake`). The kinds in `hack/live/live.yaml` run the
same steps against a real GitLab (`TestEveryKindLive`; `task live:gitlab` starts GitLab CE in Docker, on an offload VM);
`hack/live/records.json` holds each one's last result, and `zz_generated.report.md`
marks those that passed `live`. Treat the others as untested against the real API.

## How it works

The kinds are generated, not hand-written. `hack/gen/vendor.yaml` pins
GitLab's OpenAPI spec; [krm-rest-runtime](https://github.com/highfivelabs/krm-rest-runtime)'s
generator finds every resource the API exposes in a create/read/update/delete
shape, keeps those that stand in for a Terraform resource in the gap list
(`hack/gen/terraform-gaps.json`), and writes:

- `types.yaml`: per kind, its API calls, path parameters and Terraform equivalents
- `config/crds/`: one CRD per kind, its spec the API's request body
- `zz_generated.report.md`: the full list

One generic manager (`cmd/manager`) runs every kind on krm-rest-runtime's
reconciler: it creates the resource, reads it back every 10 minutes and
puts back anything changed outside Kubernetes, and deletes it with the
object. Spec fields keep GitLab's own names, so the API reference
applies field for field. Path parameters are spec fields too.

Hand corrections to the automatic matching (a Terraform type matched to
the wrong API path, or not matched) are in `vendor.yaml`'s `overrides`.
Where GitLab's spec describes an API in a form the generator cannot pair
(each integration's GET and DELETE exist only once, under
`/integrations/{slug}`), `hack/gen/supplement/` holds a hand-made OpenAPI
supplement, listed under `specs:` in `vendor.yaml`; each names its sources
at the top. Resources GitLab manages only through GraphQL (compliance
frameworks, saved replies, dependency proxy settings, ...) have no OpenAPI
description: each is a hand-written file in `hack/gen/graphql/` (its
documents, as the Terraform provider sends them, and how the spec fills
their variables), naming its sources at the top; `vendor.yaml`'s `graphql`
names the endpoint, `/api/graphql`. An epic board is made and changed over
GraphQL but read over REST: its file mixes the two. REST resources whose
calls no OpenAPI item pairs as one (a user's identity, written by the
user's update and deleted on a path of its own; one field of a group, at
the Group kind's path) are hand-written files in `hack/gen/kinds/`, in the
same format, their calls REST.

## Install

```sh
kubectl kustomize config/default | KO_DOCKER_REPO=<registry> ko resolve -f - | kubectl apply --server-side -f -
```

Then, in each namespace that manages GitLab, a Secret with
`token` and a Connection named `default`
(`config/samples/connection.yaml`). Objects use it unless
`spec.connectionRef.name` names another. Secret values (tokens, passwords,
secret values) go in a Kubernetes Secret, not the spec:
`spec.secretRefs: {<field>: {name, key}}` fills that body field.

To run only some API groups, install those groups' CRDs from `config/crds`
and pass `--groups` to the manager.

## Kinds

| Kind | Terraform equivalent | Shape | Read |
| --- | --- | --- | --- |
| `admin.gitlab.hfl.dev/v1alpha1` `AdminRole` | `gitlab_admin_role` | crud | `GET /admin_member_roles` (finds `id`) |
| `application.gitlab.hfl.dev/v1alpha1` `Application` | `gitlab_application` | crud | `GET /user/applications/{id}` |
| `application.gitlab.hfl.dev/v1alpha1` `ApplicationAppearance` | `gitlab_application_appearance` | settings | `GET /application/appearance` |
| `application.gitlab.hfl.dev/v1alpha1` `ApplicationSettings` | `gitlab_application_settings` | settings | `GET /application/settings` |
| `branch.gitlab.hfl.dev/v1alpha1` `Branch` | `gitlab_branch` | crud | `GET /projects/{id}/repository/branches/{branch}` |
| `branch.gitlab.hfl.dev/v1alpha1` `BranchProtection` | `gitlab_branch_protection` | crud | `GET /projects/{id}/protected_branches/{name}` |
| `cluster.gitlab.hfl.dev/v1alpha1` `ClusterAgent` | `gitlab_cluster_agent` | crud | `GET /projects/{id}/cluster_agents/{agent_id}` |
| `cluster.gitlab.hfl.dev/v1alpha1` `ClusterAgentToken` | `gitlab_cluster_agent_token` | crud | `GET /projects/{id}/cluster_agents/{agent_id}/tokens/{token_id}` |
| `compliance.gitlab.hfl.dev/v1alpha1` `ComplianceFramework` | `gitlab_compliance_framework` | crud | GraphQL `ComplianceFramework` (finds `id`) |
| `compliance.gitlab.hfl.dev/v1alpha1` `ComplianceFrameworkFromTemplate` | `gitlab_compliance_framework_from_template` | crud | GraphQL `ComplianceFrameworkFromTemplate` (finds `id`) |
| `compliance.gitlab.hfl.dev/v1alpha1` `ComplianceRequirement` | `gitlab_compliance_requirement` | crud | GraphQL `ComplianceRequirements` (finds `id`) |
| `deploy.gitlab.hfl.dev/v1alpha1` `DeployKey` | `gitlab_deploy_key` | crud | `GET /projects/{id}/deploy_keys/{key_id}` |
| `deploy.gitlab.hfl.dev/v1alpha1` `DeployKeyEnable` | `gitlab_deploy_key_enable` | crud | `GET /projects/{id}/deploy_keys/{enabled_key_id}` |
| `global.gitlab.hfl.dev/v1alpha1` `GlobalLevelNotifications` | `gitlab_global_level_notifications` | settings | `GET /notification_settings` |
| `group.gitlab.hfl.dev/v1alpha1` `Group` | `gitlab_group` | crud | `GET /groups/{id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupAccessToken` | `gitlab_group_access_token` | crud | `GET /groups/{id}/access_tokens/{token_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupBadge` | `gitlab_group_badge` | crud | `GET /groups/{id}/badges/{badge_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupBranchProtection` | `gitlab_group_branch_protection` | crud | `GET /groups/{id}/protected_branches/{name}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupCluster` | `gitlab_group_cluster` | crud | `GET /groups/{id}/clusters/{cluster_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupCustomAttribute` | `gitlab_group_custom_attribute` | upsert | `GET /groups/{id}/custom_attributes/{key}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupDependencyProxy` | `gitlab_group_dependency_proxy` | settings | GraphQL `GroupDependencyProxySetting` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupDependencyProxyImageTtlPolicy` | `gitlab_group_dependency_proxy_image_ttl_policy` | settings | GraphQL `GroupDependencyProxyImageTtlPolicy` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupDeployToken` | `gitlab_group_deploy_token` | crud | `GET /groups/{id}/deploy_tokens/{token_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupEpicBoard` | `gitlab_group_epic_board` | crud | `GET /groups/{groupPath}/epic_boards/{id}` (made and changed over GraphQL) |
| `group.gitlab.hfl.dev/v1alpha1` `GroupHook` | `gitlab_group_hook` | crud | `GET /groups/{id}/hooks/{hook_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupIntegrationDatadog` | `gitlab_group_integration_datadog` | upsert | `GET /groups/{id}/integrations/datadog` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupIntegrationHarbor` | `gitlab_group_integration_harbor` | upsert | `GET /groups/{id}/integrations/harbor` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupIntegrationJira` | `gitlab_group_integration_jira` | upsert | `GET /groups/{id}/integrations/jira` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupIntegrationMattermost` | `gitlab_group_integration_mattermost` | upsert | `GET /groups/{id}/integrations/mattermost` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupIntegrationMicrosoftTeams` | `gitlab_group_integration_microsoft_teams` | upsert | `GET /groups/{id}/integrations/microsoft-teams` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupIssueBoard` | `gitlab_group_issue_board` | crud | `GET /groups/{id}/boards/{board_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupLabel` | `gitlab_group_label` | crud | `GET /groups/{id}/labels/{name}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupLdapLink` | `gitlab_group_ldap_link` | assoc | `GET /groups/{id}/ldap_group_links` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupLevelMrApprovals` | `gitlab_group_level_mr_approvals` | settings | `GET /groups/{id}/merge_request_approval_setting` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupMembership` | `gitlab_group_membership` | crud | `GET /groups/{id}/members/{user_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupProjectFileTemplate` | `gitlab_group_project_file_template` | upsert | `GET /groups/{id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupProtectedEnvironment` | `gitlab_group_protected_environment` | crud | `GET /groups/{id}/protected_environments/{name}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupSamlLink` | `gitlab_group_saml_link` | crud | `GET /groups/{id}/saml_group_links/{saml_group_name}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupSavedReply` | `gitlab_group_saved_reply` | crud | GraphQL `GroupSavedReply` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupSecurityPolicyAttachment` | `gitlab_group_security_policy_attachment` | upsert | GraphQL `GroupSecurityPolicyProject` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupServiceAccount` | `gitlab_group_service_account` | crud | `GET /groups/{id}/service_accounts/{user_id}` |
| `group.gitlab.hfl.dev/v1alpha1` `GroupServiceAccountAccessToken` | `gitlab_group_service_account_access_token` | crud | `GET /groups/{id}/service_accounts/{user_id}/personal_access_tokens` (finds `id`) |
| `group.gitlab.hfl.dev/v1alpha1` `GroupShareGroup` | `gitlab_group_share_group` | crud | `GET /groups/{id}` (finds `group_id`) |
| `group.gitlab.hfl.dev/v1alpha1` `GroupVariable` | `gitlab_group_variable` | crud | `GET /groups/{id}/variables/{key}` |
| `instance.gitlab.hfl.dev/v1alpha1` `InstanceCluster` | `gitlab_instance_cluster` | crud | `GET /admin/clusters/{cluster_id}` |
| `instance.gitlab.hfl.dev/v1alpha1` `InstanceServiceAccount` | `gitlab_instance_service_account` | crud | `GET /users/{user_id}` |
| `instance.gitlab.hfl.dev/v1alpha1` `InstanceVariable` | `gitlab_instance_variable` | crud | `GET /admin/ci/variables/{key}` |
| `integration.gitlab.hfl.dev/v1alpha1` `IntegrationSlack` | `gitlab_integration_slack` | upsert | `GET /projects/{id}/integrations/slack` |
| `member.gitlab.hfl.dev/v1alpha1` `MemberRole` | `gitlab_member_role` | crud | `GET /member_roles` (finds `id`) |
| `pages.gitlab.hfl.dev/v1alpha1` `PagesDomain` | `gitlab_pages_domain` | crud | `GET /projects/{id}/pages/domains/{domain}` |
| `personal.gitlab.hfl.dev/v1alpha1` `PersonalAccessToken` | `gitlab_personal_access_token` | crud | `GET /personal_access_tokens/{id}` |
| `pipeline.gitlab.hfl.dev/v1alpha1` `PipelineSchedule` | `gitlab_pipeline_schedule` | crud | `GET /projects/{id}/pipeline_schedules/{pipeline_schedule_id}` |
| `pipeline.gitlab.hfl.dev/v1alpha1` `PipelineScheduleVariable` | `gitlab_pipeline_schedule_variable` | crud | `GET /projects/{id}/pipeline_schedules/{pipeline_schedule_id}/variables/{key}` |
| `pipeline.gitlab.hfl.dev/v1alpha1` `PipelineTrigger` | `gitlab_pipeline_trigger` | crud | `GET /projects/{id}/triggers/{trigger_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `Project` | `gitlab_project` | crud | `GET /projects/{id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectAccessToken` | `gitlab_project_access_token` | crud | `GET /projects/{id}/access_tokens/{token_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectApprovalRule` | `gitlab_project_approval_rule`, `gitlab_project_approval_rules` | crud | `GET /projects/{id}/approval_rules/{approval_rule_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectBadge` | `gitlab_project_badge` | crud | `GET /projects/{id}/badges/{badge_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectCicdCatalog` | `gitlab_project_cicd_catalog` | upsert | GraphQL `ProjectCatalogResource` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectCluster` | `gitlab_project_cluster` | crud | `GET /projects/{id}/clusters/{cluster_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectComplianceFrameworks` | `gitlab_project_compliance_frameworks` | upsert | GraphQL `ProjectComplianceFrameworks` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectContainerRepositoryProtection` | `gitlab_project_container_repository_protection` | crud | `GET /projects/{id}/registry/protection/repository/rules` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectContainerScanning` | `gitlab_project_container_scanning` | settings | GraphQL `GetContainerScanningForRegistry` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectContainerTagProtection` | `gitlab_project_container_tag_protection` | crud | `GET /projects/{id}/registry/protection/tag/rules` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectCustomAttribute` | `gitlab_project_custom_attribute` | upsert | `GET /projects/{id}/custom_attributes/{key}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectDeployToken` | `gitlab_project_deploy_token` | crud | `GET /projects/{id}/deploy_tokens/{token_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectEnvironment` | `gitlab_project_environment` | crud | `GET /projects/{id}/environments/{environment_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectErrorTrackingClientKey` | `gitlab_project_error_tracking_client_key` | crud | `GET /projects/{id}/error_tracking/client_keys` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectErrorTrackingSettings` | `gitlab_project_error_tracking_settings` | settings | `GET /projects/{id}/error_tracking/settings` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectExternalStatusCheck` | `gitlab_project_external_status_check` | crud | `GET /projects/{id}/external_status_checks` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectFeatureFlag` | `gitlab_project_feature_flag` | crud | `GET /projects/{id}/feature_flags/{feature_flag_name}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectFeatureFlagUserList` | `gitlab_project_feature_flag_user_list` | crud | `GET /projects/{id}/feature_flags_user_lists/{iid}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectFreezePeriod` | `gitlab_project_freeze_period` | crud | `GET /projects/{id}/freeze_periods/{freeze_period_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectHook` | `gitlab_project_hook` | crud | `GET /projects/{id}/hooks/{hook_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationCustomIssueTracker` | `gitlab_project_integration_custom_issue_tracker` | upsert | `GET /projects/{id}/integrations/custom-issue-tracker` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationDatadog` | `gitlab_project_integration_datadog` | upsert | `GET /projects/{id}/integrations/datadog` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationEmailsOnPush` | `gitlab_project_integration_emails_on_push` | upsert | `GET /projects/{id}/integrations/emails-on-push` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationExternalWiki` | `gitlab_project_integration_external_wiki` | upsert | `GET /projects/{id}/integrations/external-wiki` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationGithub` | `gitlab_project_integration_github` | upsert | `GET /projects/{id}/integrations/github` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationGoogleChat` | `gitlab_project_integration_google_chat` | upsert | `GET /projects/{id}/integrations/hangouts-chat` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationHarbor` | `gitlab_project_integration_harbor` | upsert | `GET /projects/{id}/integrations/harbor` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationJenkins` | `gitlab_project_integration_jenkins` | upsert | `GET /projects/{id}/integrations/jenkins` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationJira` | `gitlab_project_integration_jira` | upsert | `GET /projects/{id}/integrations/jira` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationMatrix` | `gitlab_project_integration_matrix` | upsert | `GET /projects/{id}/integrations/matrix` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationMattermost` | `gitlab_project_integration_mattermost` | upsert | `GET /projects/{id}/integrations/mattermost` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationMicrosoftTeams` | `gitlab_project_integration_microsoft_teams` | upsert | `GET /projects/{id}/integrations/microsoft-teams` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationPipelinesEmail` | `gitlab_project_integration_pipelines_email` | upsert | `GET /projects/{id}/integrations/pipelines-email` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationRedmine` | `gitlab_project_integration_redmine` | upsert | `GET /projects/{id}/integrations/redmine` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationTelegram` | `gitlab_project_integration_telegram` | upsert | `GET /projects/{id}/integrations/telegram` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIntegrationYoutrack` | `gitlab_project_integration_youtrack` | upsert | `GET /projects/{id}/integrations/youtrack` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIssue` | `gitlab_project_issue` | crud | `GET /projects/{id}/issues/{issue_iid}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIssueBoard` | `gitlab_project_issue_board` | crud | `GET /projects/{id}/boards/{board_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectIssueLink` | `gitlab_project_issue_link` | crud | `GET /projects/{id}/issues/{issue_iid}/links/{issue_link_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectJobTokenScope` | `gitlab_project_job_token_scope`, `gitlab_project_job_token_scopes` | settings | `GET /projects/{id}/job_token_scope` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectLabel` | `gitlab_project_label` | crud | `GET /projects/{id}/labels/{name}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectLevelMrApprovals` | `gitlab_project_level_mr_approvals` | settings | `GET /projects/{id}/merge_request_approval_setting` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectLevelNotifications` | `gitlab_project_level_notifications` | settings | `GET /projects/{id}/notification_settings` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectMembership` | `gitlab_project_membership` | crud | `GET /projects/{id}/members/{user_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectMergeRequestNote` | `gitlab_project_merge_request_note` | crud | `GET /projects/{id}/merge_requests/{noteable_id}/notes/{note_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectMilestone` | `gitlab_project_milestone` | crud | `GET /projects/{id}/milestones/{milestone_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectPackageDependencyProxy` | `gitlab_project_package_dependency_proxy` | settings | GraphQL `ProjectDependencyProxyPackagesSetting` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectPackageProtectionRule` | `gitlab_project_package_protection_rule` | crud | `GET /projects/{id}/packages/protection/rules` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectPagesSettings` | `gitlab_project_pages_settings` | settings | `GET /projects/{id}/pages` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectProtectedEnvironment` | `gitlab_project_protected_environment` | crud | `GET /projects/{id}/protected_environments/{name}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectPullMirror` | `gitlab_project_pull_mirror` | settings | `GET /projects/{id}/mirror/pull` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectPushMirror` | `gitlab_project_push_mirror` | crud | `GET /projects/{id}/remote_mirrors/{mirror_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectPushRules` | `gitlab_project_push_rules` | upsert | `GET /projects/{id}/push_rule` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectRunnerEnablement` | `gitlab_project_runner_enablement` | crud | `GET /projects/{id}/runners` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectSavedReply` | `gitlab_project_saved_reply` | crud | GraphQL `ProjectSavedReply` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectSecretDetectionValidityChecks` | `gitlab_project_secret_detection_validity_checks` | settings | GraphQL `SecurityConfigurationValidityChecks` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectSecureFile` | `gitlab_project_secure_file` | crud | `GET /projects/{id}/secure_files/{secure_file_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectSecurityPolicyAttachment` | `gitlab_project_security_policy_attachment` | upsert | GraphQL `ProjectSecurityPolicyProject` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectSecuritySettings` | `gitlab_project_security_settings` | settings | `GET /projects/{id}/security_settings` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectServiceAccount` | `gitlab_project_service_account` | crud | `GET /projects/{id}/service_accounts/{user_id}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectServiceAccountAccessToken` | `gitlab_project_service_account_access_token` | crud | `GET /projects/{id}/service_accounts/{user_id}/personal_access_tokens` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectShareGroup` | `gitlab_project_share_group` | crud | `GET /projects/{id}` (finds `group_id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectTag` | `gitlab_project_tag` | crud | `GET /projects/{id}/repository/tags/{tag_name}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectTargetBranchRule` | `gitlab_project_target_branch_rule` | crud | GraphQL `ProjectTargetBranchRules` (finds `id`) |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectVariable` | `gitlab_project_variable` | crud | `GET /projects/{id}/variables/{key}` |
| `project.gitlab.hfl.dev/v1alpha1` `ProjectWikiPage` | `gitlab_project_wiki_page` | crud | `GET /projects/{id}/wikis/{slug}` |
| `release.gitlab.hfl.dev/v1alpha1` `Release` | `gitlab_release` | crud | `GET /projects/{id}/releases/{tag_name}` |
| `release.gitlab.hfl.dev/v1alpha1` `ReleaseLink` | `gitlab_release_link` | crud | `GET /projects/{id}/releases/{tag_name}/assets/links/{link_id}` |
| `repository.gitlab.hfl.dev/v1alpha1` `RepositoryFile` | `gitlab_repository_file` | upsert | `GET /projects/{id}/repository/files/{file_path}` |
| `runner.gitlab.hfl.dev/v1alpha1` `RunnerController` | `gitlab_runner_controller` | crud | `GET /runner_controllers/{id}` |
| `runner.gitlab.hfl.dev/v1alpha1` `RunnerControllerInstanceScope` | `gitlab_runner_controller_instance_scope` | upsert | `GET /runner_controllers/{id}/scopes` (its `instance_level_scopings`) |
| `runner.gitlab.hfl.dev/v1alpha1` `RunnerControllerRunnerScope` | `gitlab_runner_controller_runner_scope` | upsert | `GET /runner_controllers/{id}/scopes` (finds `runner_id` in `runner_level_scopings`) |
| `runner.gitlab.hfl.dev/v1alpha1` `RunnerControllerToken` | `gitlab_runner_controller_token` | crud | `GET /runner_controllers/{runner_controller_id}/tokens/{id}` |
| `system.gitlab.hfl.dev/v1alpha1` `SystemHook` | `gitlab_system_hook` | crud | `GET /hooks/{hook_id}` |
| `tag.gitlab.hfl.dev/v1alpha1` `TagProtection` | `gitlab_tag_protection` | crud | `GET /projects/{id}/protected_tags/{name}` |
| `topic.gitlab.hfl.dev/v1alpha1` `Topic` | `gitlab_topic` | crud | `GET /topics/{id}` |
| `user.gitlab.hfl.dev/v1alpha1` `User` | `gitlab_user` | crud | `GET /users/{id}` |
| `user.gitlab.hfl.dev/v1alpha1` `UserAvatar` | `gitlab_user_avatar` | settings | `GET /users/{id}` |
| `user.gitlab.hfl.dev/v1alpha1` `UserCustomAttribute` | `gitlab_user_custom_attribute` | upsert | `GET /users/{id}/custom_attributes/{key}` |
| `user.gitlab.hfl.dev/v1alpha1` `UserGpgkey` | `gitlab_user_gpgkey` | crud | `GET /user/gpg_keys/{key_id}` |
| `user.gitlab.hfl.dev/v1alpha1` `UserIdentity` | `gitlab_user_identity` | upsert | `GET /users/{id}` (finds `provider` in `identities`) |
| `user.gitlab.hfl.dev/v1alpha1` `UserImpersonationToken` | `gitlab_user_impersonation_token` | crud | `GET /users/{user_id}/impersonation_tokens/{impersonation_token_id}` |
| `user.gitlab.hfl.dev/v1alpha1` `UserRunner` | `gitlab_user_runner` | crud | `GET /runners/{runner_id}` |
| `user.gitlab.hfl.dev/v1alpha1` `UserSavedReply` | `gitlab_user_saved_reply` | crud | GraphQL `UserSavedReply` |
| `user.gitlab.hfl.dev/v1alpha1` `UserSshkey` | `gitlab_user_sshkey` | crud | `GET /user/keys/{key_id}` |
| `value.gitlab.hfl.dev/v1alpha1` `GroupValueStreamAnalytics` | `gitlab_value_stream_analytics` | crud | GraphQL `GroupValueStream` (finds `id`) |
| `value.gitlab.hfl.dev/v1alpha1` `ProjectValueStreamAnalytics` | `gitlab_value_stream_analytics` | crud | GraphQL `ProjectValueStream` (finds `id`) |

## Notes on some kinds

- Kinds whose read is "finds" (GitLab lists them but cannot get one) read
  the first 100 of the list. Those GitLab cannot change (error tracking
  client keys, runner enablements, service account tokens, custom roles)
  and container tag protection rules (Terraform re-creates one on any
  change) have no update: a changed spec is reported as drift (delete and
  recreate the object). External status checks and container repository
  and package protection rules are updated with the item's PUT or PATCH.
  `MemberRole` and `AdminRole` are instance-level custom roles
  (self-managed); Terraform makes them over GraphQL.
- `GroupShareGroup` and `ProjectShareGroup` are read, as Terraform reads
  them, from the `shared_with_groups` of the group or project shared. GitLab
  reads the access level back as `group_access_level`, so a changed
  `group_access` is not seen: delete and recreate the object (Terraform
  replaces it). `ProjectShareGroup` reads with `statistics=false`, GitLab's
  default, only so that the fake API tells its read apart from the
  `Project` kind's.
- `DeployKeyEnable` enables an existing deploy key (`spec.keyID`) for a
  project; `can_push` is applied by an update after enabling, as Terraform
  does. Its ID is the key's.
- `ProjectLevelMrApprovals` uses `/projects/{id}/merge_request_approval_setting`
  (`allow_author_approval`, ...), not Terraform's `POST /projects/{id}/approvals`.
  Approval settings read back as `{value, locked}`, so they are written,
  not compared for drift.
- `UserSshkey` and `UserGpgkey` are the token owner's keys (`/user/...`);
  Terraform's `user_id` form for other users (admin) is not covered.
- Settings kinds (`ProjectPullMirror`, `ProjectPagesSettings`, notification
  and approval settings) leave the settings as they are when the object is
  deleted; Terraform disables a pull mirror on destroy.
- Certificate-based clusters (`GroupCluster`, `ProjectCluster`,
  `InstanceCluster`) are deprecated by GitLab and off by default on
  self-managed instances. `RunnerController`, its token and its scopes
  need GitLab 19.6. `RunnerControllerInstanceScope` is there or not (POST
  adds it, DELETE removes it); `RunnerControllerRunnerScope` names one
  instance runner; neither has anything to change.
- `GroupEpicBoard` is made, changed and destroyed over GraphQL and read
  over REST, as Terraform reads it; its ID is the board's number (the end
  of the global ID GraphQL answers). Its `name`, `hide_backlog_list` and
  `hide_closed_list` are covered; Terraform's `lists` (made one call per
  list after the board) are not.
- `UserIdentity` is written by the user's update (`PUT /users/{id}` with
  `provider` and `extern_uid`), read from the user's `identities` and
  removed by `DELETE /users/{id}/identities/{provider}`.
  `GroupProjectFileTemplate` is the group's `file_template_project_id`
  alone; deleting the object clears it (the group stays). `UserAvatar`
  uploads the image (`avatar`, a file: its bytes in `contentBase64`) with
  the user's update, a multipart body; GitLab answers only a URL for it, so
  the image is written each time the spec changes it and not compared, and
  deleting the object leaves the avatar (GitLab cannot remove one). These
  need an administrator's token; Terraform's `token` for a user's own
  avatar is not covered.
- The GraphQL kinds (`Read` column: GraphQL) post to `/api/graphql`, beside
  the Connection's `/api/v4`. GitLab's GraphQL names a group or project by
  its full path in some calls and by its global ID in others; where a
  kind's calls need both, its spec has `fullPath` and the numeric
  `groupId` or `projectId` (sent as `gid://gitlab/Group/<id>`), and the
  saved reply, framework and rule IDs are global IDs (`status.id`).
  `ProjectContainerScanning`, `ProjectSecretDetectionValidityChecks`,
  `GroupDependencyProxy`, `GroupDependencyProxyImageTtlPolicy` and
  `ProjectPackageDependencyProxy` are settings kinds: deleting the object
  leaves them as they are (Terraform turns them off or restores them).
  `ProjectCicdCatalog` lists the project in the CI/CD Catalog while the
  object exists, and un-lists it when the object is deleted.
  `ProjectComplianceFrameworks` holds the whole list (deleting the object
  empties it). `ComplianceFrameworkFromTemplate`'s `templateId` is used only
  when it is made. `ProjectTargetBranchRule` cannot be updated (a change is
  drift: delete and recreate the object), as Terraform replaces it.
- Many kinds need GitLab Premium or Ultimate, or an administrator's token;
  they are proven on the fake only (readiness `fake`).

## Not covered

<!-- BEGIN generated: not covered (krmgen.py, from vendor.yaml hardBlocks and draftNotes) -->
Every one of the 142 Terraform gap types has a kind.
<!-- END generated: not covered -->

Limits of kinds that cover a Terraform type:

- `ComplianceRequirement` sets a requirement's name and description only:
  Terraform's `controls` and `external_controls` are written as one list
  beside it (an internal control's expression a JSON string), read back as
  a connection of controls with IDs of their own, and an external control's
  secret token is never read back.
- `gitlab_value_stream_analytics` is two kinds, `GroupValueStreamAnalytics`
  and `ProjectValueStreamAnalytics`, by the namespace the value stream is
  in; a stage's labels are written as label global IDs and compared with
  the labels read back. A change is drift: delete and recreate the object,
  as Terraform replaces it.

## For agents (MCP)

`cmd/mcp` serves this repository's kinds over the Model Context Protocol
(stdio), from `types.yaml`, `config/crds` and the live tests' records.
`.mcp.json` registers it, so an agent session opened in this repository
has it without setup. Elsewhere, run it from the repository root:

```sh
go run ./cmd/mcp
```

Its tools: `list_kinds`, `find_kinds_for_terraform`, `describe_kind` (every
field, the REST calls, the live record), `example` (the live-tested spec
where there is one), `validate_manifest` (the CRD schema, as the API server
checks it) and `plan_on_fake` (the controller run against the fake API,
with every REST call it makes). Nothing it does reaches the real API.
krm-rest-runtime's README ("For agents") has the details.

## Regenerate

```sh
hack/gen/generate.sh   # needs python3 + pyyaml, and krm-rest-runtime beside this repo
go test ./...
```
