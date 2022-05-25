# Remote Jenkins Job Trigger
Trigger a job on a remote Jenkins instance from a Jenkins job and report the results back using Jenkins API

Shell is not a language I have a lot of experience with, so I'm sure this can be greatly refactored.

Due to organizational constraints I needed the ability to trigger a test execution build on a remote Jenkins server in another network that I have little control over. I needed to report the test execution results & artifact back to the originating build (show the nice JUNIT test results graph).
