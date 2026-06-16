SHELL := /bin/bash

.PHONY: sim test lint clean check

sim: test

test:
	./scripts/test.sh

lint:
	./scripts/lint.sh

clean:
	./scripts/clean.sh

check: lint test
