## MODIFIED Requirements

### Requirement: URL sanitization not applied to org-roam output
The system SHALL NOT apply URL sanitization (defanging) to url-capture org-roam output. org-roam requires real URLs for proper link resolution and backlink functionality. `sem-security-sanitize-urls` SHALL NOT be used on the generated org-roam node body or `#+ROAM_REFS` values, and persisted url-capture output SHALL retain canonical `http://` and `https://` forms.

#### Scenario: Real URLs preserved in org-roam
- **WHEN** url-capture writes an org-roam node to `/data/org-roam/`
- **THEN** URLs remain in their original `http://` or `https://` format

#### Scenario: URL sanitization excluded from url-capture
- **WHEN** `sem-url-capture-process` generates org-roam output
- **THEN** `sem-security-sanitize-urls` is NOT called on the output

#### Scenario: Defanged forms are rejected in persisted url-capture output
- **WHEN** url-capture output is validated before write
- **THEN** persisted trusted URL fields do not contain `hxxp://` or `hxxps://` forms

### Requirement: Source URL visible in Summary section
The system SHALL write the source URL as the first line of the `* Summary` section body as a plain org-mode link: `Source: [[URL][URL]]`. The URL in this line SHALL match the canonical trusted source URL used for capture. `#+ROAM_REFS` SHALL still be written for backlink resolution and SHALL use the same canonical URL.

#### Scenario: Source URL in Summary
- **WHEN** url-capture writes a generated org-roam node
- **THEN** the first line of `* Summary` is `Source: [[URL][URL]]`
- **AND** URL is canonical `http://` or `https://` form

#### Scenario: ROAM_REFS preserved for backlink resolution
- **WHEN** url-capture writes a generated org-roam node
- **THEN** `#+ROAM_REFS: URL` is included in the file for org-roam backlink resolution
- **AND** URL matches the Summary source URL exactly

## ADDED Requirements

### Requirement: URL defanging contract is consistent across runtime and documentation
The system SHALL define one authoritative URL-defanging contract and keep runtime behavior and repository documentation aligned with that contract for task output, RSS digest output, and url-capture output.

#### Scenario: Tasks and RSS outputs use defanged URL representation
- **WHEN** task or RSS artifacts are produced for operator-facing text output
- **THEN** URLs follow the documented defanging rules for those output types

#### Scenario: url-capture output remains canonical
- **WHEN** org-roam url-capture artifacts are produced
- **THEN** URLs remain canonical and are not defanged

#### Scenario: Documentation states output-specific URL behavior
- **WHEN** operators consult repository documentation for URL handling
- **THEN** documentation explicitly distinguishes defanged outputs from canonical url-capture outputs
