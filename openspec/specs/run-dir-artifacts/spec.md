# Specification: run-dir-artifacts

## Purpose

Define requirements for test run directory creation and artifact collection.

## ADDED Requirements

### Requirement: Run directory is created with timestamp
The system SHALL create a timestamped directory `test-results/YYYY-MM-DD-HH-MM-SS-run/` at the start of each test run and SHALL collect both task-flow artifacts and URL-capture org-roam artifacts with baseline-versus-new visibility.

#### Scenario: Test results directory is created if absent
- **WHEN** the test script starts and `test-results/` does not exist
- **THEN** the script MUST create the `test-results/` directory

#### Scenario: Run directory uses correct timestamp format
- **WHEN** a test run starts
- **THEN** the run directory MUST be named using the format produced by `date +%Y-%m-%d-%H-%M-%S`

#### Scenario: Test results directory is git-ignored
- **WHEN** the test script runs
- **THEN** the `test-results/` directory MUST be git-ignored

#### Scenario: Inbox is copied to run directory
- **WHEN** artifact collection runs
- **THEN** a copy of `dev/integration/testing-resources/inbox-tasks.org` MUST be saved as `inbox-sent.org`

#### Scenario: Tasks org is fetched from WebDAV
- **WHEN** artifact collection runs
- **THEN** the script MUST GET `http://localhost:16065/data/tasks.org` and save it as `tasks.org`

#### Scenario: Sem log is fetched from WebDAV
- **WHEN** artifact collection runs
- **THEN** the script MUST GET `http://localhost:16065/data/sem-log.org` and save it as `sem-log.org`

#### Scenario: Errors org is fetched from WebDAV
- **WHEN** artifact collection runs
- **THEN** the script MUST attempt to GET `http://localhost:16065/data/errors.org` and save it as `errors.org`
- **AND** if the file returns HTTP 404, the script MUST skip silently

#### Scenario: URL-capture org-roam artifacts are collected
- **WHEN** artifact collection runs
- **THEN** URL-capture org-roam output files from the runtime test org-roam directory MUST be copied into the run directory

#### Scenario: Baseline versus new capture visibility is preserved
- **WHEN** inspecting URL-capture artifacts in a run directory
- **THEN** baseline fixture files and newly generated capture files MUST be distinguishable

#### Scenario: Log files are collected
- **WHEN** artifact collection runs
- **THEN** all files matching `./logs/messages-*.log` MUST be copied to the run directory with filenames preserved

#### Scenario: Container logs are collected
- **WHEN** artifact collection runs
- **THEN** `podman logs sem-emacs 2>&1` MUST be saved as `emacs-container.log`
- **AND** `podman logs sem-webdav 2>&1` MUST be saved as `webdav-container.log`

#### Scenario: Validation output is saved
- **WHEN** artifact collection runs
- **THEN** stdout and stderr of all assertion steps MUST be tee'd to `validation.txt`

#### Scenario: Artifacts collected before container teardown
- **WHEN** the test script exits
- **THEN** artifact collection MUST run BEFORE containers are stopped (trap fires after collection)

#### Scenario: HTTP failure handling for tasks.org
- **WHEN** GET for `tasks.org` returns HTTP non-200
- **THEN** the script MUST save an empty placeholder file and note the failure in `validation.txt`
