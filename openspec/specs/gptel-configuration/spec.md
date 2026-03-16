## Purpose

This capability defines the gptel configuration for using OpenRouter as the LLM backend.

## Requirements

### Requirement: gptel configured with OpenRouter backend
The system SHALL configure gptel to use OpenRouter as the LLM backend. The configuration SHALL be done in `init.el`.

#### Scenario: OpenRouter backend created
- **WHEN** `init.el` loads
- **THEN** `gptel-make-openai` is called with OpenRouter settings

### Requirement: API key read from environment variable
The API key SHALL be provided as a lambda wrapping `getenv` — never as a hardcoded string. The key SHALL be read from `OPENROUTER_KEY` environment variable.

#### Scenario: API key from env var
- **WHEN** gptel is configured
- **THEN** the key is read via `(lambda () (getenv "OPENROUTER_KEY"))`

#### Scenario: No hardcoded API key
- **WHEN** inspecting `init.el`
- **THEN** no hardcoded API key string is present

### Requirement: Model read from environment variable
The model SHALL be read from the `OPENROUTER_MODEL` environment variable at call time — never hardcoded in Elisp.

#### Scenario: Model from env var
- **WHEN** gptel is configured
- **THEN** the model is read via `(intern (getenv "OPENROUTER_MODEL"))`

#### Scenario: No hardcoded model
- **WHEN** inspecting `init.el`
- **THEN** no hardcoded model string is present (except in the list passed to `:models`)

### Requirement: Environment variables passed via docker-compose
`OPENROUTER_KEY` and `OPENROUTER_MODEL` SHALL be declared in `.env` and passed to the Emacs container via docker-compose `environment:` block.

#### Scenario: Env vars in docker-compose
- **WHEN** inspecting `docker-compose.yml`
- **THEN** `OPENROUTER_KEY` and `OPENROUTER_MODEL` are in the `environment:` section

### Requirement: Daemon aborts if env vars missing
If either `OPENROUTER_KEY` or `OPENROUTER_MODEL` is unset or empty at runtime, `init.el` SHALL signal an error and abort — the daemon must not start without LLM credentials.

#### Scenario: Missing OPENROUTER_KEY aborts
- **WHEN** `OPENROUTER_KEY` is not set or empty
- **THEN** `init.el` signals an error and the daemon does not start

#### Scenario: Missing OPENROUTER_MODEL aborts
- **WHEN** `OPENROUTER_MODEL` is not set or empty
- **THEN** `init.el` signals an error and the daemon does not start

### Requirement: gptel-backend and gptel-model set as globals
The `gptel-backend` and `gptel-model` SHALL be set as globals in `init.el` immediately after `gptel-make-openai` so all modules use the configured backend without re-specifying it.

#### Scenario: Globals set after backend creation
- **WHEN** `init.el` configures gptel
- **THEN** `(setq gptel-backend ...)` and `(setq gptel-model ...)` are executed

### Requirement: Configuration pattern followed
The required configuration pattern in `init.el` is:
```elisp
(gptel-make-openai "OpenRouter"
  :host "openrouter.ai"
  :endpoint "/api/v1/chat/completions"
  :stream t
  :key (lambda () (getenv "OPENROUTER_KEY"))
  :models (list (intern (getenv "OPENROUTER_MODEL"))))
(setq gptel-backend (gptel-get-backend "OpenRouter"))
(setq gptel-model (intern (getenv "OPENROUTER_MODEL")))
```

#### Scenario: Host set to openrouter.ai
- **WHEN** gptel is configured
- **THEN** `:host` is `"openrouter.ai"`

#### Scenario: Endpoint set correctly
- **WHEN** gptel is configured
- **THEN** `:endpoint` is `"/api/v1/chat/completions"`

#### Scenario: Streaming enabled
- **WHEN** gptel is configured
- **THEN** `:stream` is `t`
