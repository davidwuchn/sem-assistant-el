## ADDED Requirements

### Requirement: Elfeed update runs four times before digest generation
The system SHALL refresh the Elfeed database four times before digest generation to ensure fresh feed content. The cron schedule SHALL be: `0 5 * * *`, `0 6 * * *`, `0 7 * * *`, `0 8 * * *` — one `emacsclient -e "(elfeed-update)"` call per hour from 5AM to 8AM.

#### Scenario: Update at 5AM
- **WHEN** the cron triggers at 5:00 AM
- **THEN** `emacsclient -e "(elfeed-update)"` is executed

#### Scenario: Update at 6AM
- **WHEN** the cron triggers at 6:00 AM
- **THEN** `emacsclient -e "(elfeed-update)"` is executed

#### Scenario: Update at 7AM
- **WHEN** the cron triggers at 7:00 AM
- **THEN** `emacsclient -e "(elfeed-update)"` is executed

#### Scenario: Update at 8AM
- **WHEN** the cron triggers at 8:00 AM
- **THEN** `emacsclient -e "(elfeed-update)"` is executed

### Requirement: elfeed-update called via emacsclient only
The system SHALL call `elfeed-update` exclusively via `emacsclient` from cron. Emacs internal timers SHALL NOT be used for this purpose.

#### Scenario: Cron invokes elfeed-update
- **WHEN** the scheduled time arrives
- **THEN** cron runs `emacsclient -e "(elfeed-update)"`

#### Scenario: No internal timer triggers update
- **WHEN** the daemon is running
- **THEN** no `run-at-time` or `idle-timer` triggers `elfeed-update`

### Requirement: No digest generation before 8AM
The system SHALL NOT trigger digest generation before 8:00 AM. The elfeed-update and digest capabilities SHALL use separate, non-overlapping cron entries.

#### Scenario: Digest blocked before 8AM
- **WHEN** the time is before 8:00 AM
- **THEN** no digest generation is triggered

### Requirement: feeds.org read via elfeed-org
The system SHALL read feed subscription list from `/data/feeds.org` via elfeed-org. This file configures which RSS/Atom feeds Elfeed subscribes to.

#### Scenario: Feeds loaded from feeds.org
- **WHEN** elfeed-org is initialized
- **THEN** it reads subscriptions from `/data/feeds.org`

### Requirement: Missing feeds.org handled gracefully
The system SHALL handle the case where `/data/feeds.org` does not exist at `elfeed-update` time. Elfeed SHALL start with an empty feed list — no error is raised, no fallback file is created.

#### Scenario: Empty feed list on missing file
- **WHEN** `/data/feeds.org` does not exist
- **THEN** elfeed starts with an empty feed list without raising an error

#### Scenario: No fallback file created
- **WHEN** `/data/feeds.org` is absent
- **THEN** the daemon does not create a fallback or template file
