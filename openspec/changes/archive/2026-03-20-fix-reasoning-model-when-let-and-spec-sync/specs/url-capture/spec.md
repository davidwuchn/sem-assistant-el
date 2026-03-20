## ADDED Requirements

### Requirement: URL sanitization not applied to org-roam output
The system SHALL NOT apply URL sanitization (defanging) to url-capture org-roam output. org-roam requires real URLs for proper link resolution and backlink functionality.

#### Scenario: Real URLs preserved in org-roam
- **WHEN** url-capture writes an org-roam node to `/data/org-roam/`
- **THEN** URLs remain in their original `http://` or `https://` format

#### Scenario: URL sanitization excluded from url-capture
- **WHEN** `sem-url-capture-process` generates org-roam output
- **THEN** `sem-security-sanitize-urls` is NOT called on the output
