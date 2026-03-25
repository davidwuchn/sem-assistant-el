## MODIFIED Requirements

### Requirement: Complete schedule defined
The system SHALL implement the following complete schedule with no gaps or overlaps:

```
*/30 * * * *  root  emacsclient -e "(sem-core-process-inbox)"
0    4 * * *  root  emacsclient -e "(sem-core-purge-inbox)"
0    5 * * *  root  emacsclient -e "(elfeed-update)"
0    6 * * *  root  emacsclient -e "(elfeed-update)"
0    7 * * *  root  emacsclient -e "(elfeed-update)"
0    8 * * *  root  emacsclient -e "(elfeed-update)"
30   9 * * *  root  emacsclient -e "(sem-rss-generate-morning-digest)"
*/15 * * * *  root  /usr/local/bin/sem-daemon-watchdog
```

#### Scenario: Inbox processing every 30 minutes
- **WHEN** every 30th minute of every hour
- **THEN** `sem-core-process-inbox` is called

#### Scenario: Purge at 4AM
- **WHEN** 4:00 AM arrives
- **THEN** `sem-core-purge-inbox` is called

#### Scenario: Elfeed update 5-8AM
- **WHEN** 5:00, 6:00, 7:00, 8:00 AM arrive
- **THEN** `elfeed-update` is called each hour

#### Scenario: RSS digest at 9:30AM
- **WHEN** 9:30 AM arrives
- **THEN** `sem-rss-generate-morning-digest` is called

#### Scenario: Watchdog executes every 15 minutes
- **WHEN** every 15th minute of every hour
- **THEN** `sem-daemon-watchdog` is called

## ADDED Requirements

### Requirement: Watchdog cron job is operational-only
The cron schedule SHALL treat the daemon liveness watchdog as an operational supervision job. The watchdog cron entry MUST NOT invoke inbox processing, purge, RSS generation, or git synchronization workflows.

#### Scenario: Watchdog command scope
- **WHEN** the watchdog cron entry executes
- **THEN** it performs only liveness probe and restart supervision behavior

#### Scenario: Business workflows remain separate
- **WHEN** business workflows are scheduled by cron
- **THEN** they are executed only by their dedicated cron entries and not by the watchdog job
