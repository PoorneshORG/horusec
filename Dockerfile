FROM zricethezav/gitleaks:v8.27.2

COPY ./services/formatters/leaks/deployments/rules.toml /rules/rules.toml
