#!/usr/bin/env bash

# Run the tests with shcov to collect coverage data
shcov -- ./tests.bats

# Generate the coverage report
shcov-show
