# Nautilus-Institute-Continuous-Integration-And-Continuous-Delivery

This challenge was inspired by GitHub Actions, which have had some [security trouble recently](https://unit42.paloaltonetworks.com/github-actions-supply-chain-attack/)

This challenge is a CI system which processes git "pull requests" in the form of uploaded git bundles.

The system reads a `.nautilus/plan/actor.x` xml file and uses that run a set of "jobs" from a list of available pre-defined job scripts

The goal is to get arbitrary command injection via uploading a pull request by exploiting several vulnerabilities in the system.

## Vulnerabilities

For information on the vulnerabilities, please see `./solver`
