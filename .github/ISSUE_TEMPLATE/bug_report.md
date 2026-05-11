name: Bug report
description: Create a report to help us improve
labels: ["bug"]
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!
  - type: textarea
    id: description
    attributes:
      label: Description
      description: A clear and concise description of what the bug is.
    validations:
      required: true
  - type: textarea
    id: reproduction
    attributes:
      label: Steps to Reproduce
      description: Steps to reproduce the behavior.
      placeholder: |
        1. ...
        2. ...
        3. ...
    validations:
      required: true
  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: A clear and concise description of what you expected to happen.
    validations:
      required: true
  - type: textarea
    id: environment
    attributes:
      label: Environment
      description: Flutter version, OS, envified version, etc.
      placeholder: |
        Flutter: 3.24.0
        OS: macOS 15.4
        envified: 2.2.1
    validations:
      required: true
  - type: textarea
    id: logs
    attributes:
      label: Logs
      description: Paste any relevant logs here.
      render: shell
  - type: checkboxes
    id: checks
    attributes:
      label: Checklist
      options:
        - label: I have searched for existing issues.
          required: true
        - label: I am using the latest version of envified.
          required: true
