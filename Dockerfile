# Copyright 2020 ZUP IT SERVICOS EM TECNOLOGIA E INOVACAO SA
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# FROM zricethezav/gitleaks:v8.27.2

# COPY ./internal/services/formatters/leaks/deployments/rules.toml /rules/rules.toml

# ENTRYPOINT []

# CMD ["/bin/sh"]

FROM zricethezav/gitleaks:v8.27.2

# Create the rules directory and fetch the official Horusec rules.toml
RUN mkdir -p /rules && \
    curl -fsSL https://raw.githubusercontent.com/ZupIT/horusec/main/internal/services/formatters/leaks/deployments/rules.toml \
    -o /rules/rules.toml

ENTRYPOINT []

CMD ["/bin/sh"]
