# XWiki User-Agent Gate

A small `javax.servlet.Filter` used by an XWiki 16.4.0 lab deployment. It accepts a request only when exactly one `User-Agent` header matches the configured value. Other requests receive HTTP 403.

Maintained for Bewhite (비와이트) by Sangjoong Kim (김상중).

This repository contains only the custom gate and deployment example. It does not contain the XWiki distribution, VM files, credentials, or training attack scripts.

## Files

- `src/main/java/lab/UserAgentGateFilter.java`: the filter.
- `src/test/java/lab/UserAgentGateFilterSmokeTest.java`: a standalone behavior check.
- `web.xml-snippet.txt`: an example filter declaration and mapping for the XWiki web application.
- `Install-XWikiUserAgentGate.ps1`: installs the JAR and filter declaration into a lab Windows deployment after backing up `web.xml`.

Build with Maven and Java 17: `mvn package`. The installer must be run by an administrator on the lab server. Read the script before applying it to another deployment.

## Deployment configuration

Provide the deployment-specific User-Agent with `-AllowedUserAgent` when running the installer. The value in `web.xml-snippet.txt` is a placeholder, not the production value. Do not commit a deployment value to this repository.
