# Travis Insights

Utility script for instrumenting Travis CI builds with New Relic. Install
this script at the top of your `.travis.yml` and every subsequent command
will be logged to New Relic Insights!

## Installation
1. Note your New Relic account number (the integer in the URL when viewing
   data in Insights).
2. Generate a New Relic Insights Insert Key in the manner described
   [here](https://docs.newrelic.com/docs/insights/new-relic-insights/custom-events/insert-custom-events-insights-api#register).
3. Add these values to your build config, ensuring that they are encrypted.
   They should be named `$NR_ACCOUNT` and `$NR_INSERT_KEY` respectively.
   You can do so either using the [Travis CLI](https://docs.travis-ci.com/user/environment-variables/#Encrypting-environment-variables)
   or by setting them in [Repository Settings](https://docs.travis-ci.com/user/environment-variables/#Defining-Variables-in-Repository-Settings)
   through the Travis UI.
4. Add the following to your `.travis.yml` file. It should be the very first
   thing run in the `before_install` build step. You may need to add this
   step in your config:

```yml
before_install:
  - curl -s https://raw.githubusercontent.com/tableau-mkt/travis-insights/master/instrument.sh > ~/.nrt.sh && source ~/.nrt.sh
```

__Warning__: You're installing a thing into your build that a) you didn't
write, and b) is pushing information to a third party (New Relic). Think
about what that means and consider doing this in a safer way. You're smart.

You may also wish to reference a specific commit rather than pointing at
the `master` branch in the `curl` call above.

## Data & Usage
Every command will be pushed to New Relic Insights with the following
properties:

- __eventType__: BuildCommand
- __ExitCode__: The exit status of the command (e.g. 0 = pass, 1 = fail)
- __Time__: The time (in seconds) when the command completed.
- __Duration__: The time (in seconds) it took for the command to complete.
- __Branch__:  For builds not triggered by a pull request this is the name
  of the branch currently being built; whereas for builds triggered by a
  pull request this is the name of the branch targeted by the pull request.
- __BuildID__: The id of the current build that Travis CI uses internally.
- __BuildNumber__: The number of the current build.
- __Commit__: The commit that the current build is testing.
- __CommitRange__: The range of commits that were included in the push or
  pull request.
- __BuildEvent__: Indicates how the build was triggered. One of `push`,
  `pull_request`, `api`, `cron`.
- __JobID__: The id of the current job that Travis CI uses internally.
- __JobNumber__: The number of the current job.
- __BuildOS__: On multi-OS builds, this value indicates the platform the
  job is running on. Values are `linux` and `osx`.
- __BuildSlug__: The slug (in form: `owner_name/repo_name`) of the repo
  currently being built.
- __Tag__: If the current build is for a git tag, this is set to the tag
  name.
- __Phase__: If the command is run during the "script" build phase, this
  is set to "Script" otherwise this is set to "Pre-Script" (useful for
  distinguishing between build _errors_ and build _fails_).

Once the data is flowing in, you'll be able to run NRQL queries like
the following:

#### Build steps that fail from most to least frequently (past week)
```sql
SELECT COUNT(*) FROM BuildCommand
WHERE ExitCode != 0
SINCE 1 week ago
FACET Command
```

#### Slowest build steps on average (today)
```sql
SELECT average(Duration) FROM BuildCommand
SINCE 1 day ago
FACET Command
```

#### Commits that broke the build (past hour)
```sql
SELECT uniques(Commit) FROM BuildCommand WHERE ExitCode != 0
```
