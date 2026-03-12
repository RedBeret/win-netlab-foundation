PYTHON ?= python3
PYTHONPATH ?= src
CONFIG ?= configs/lab.config.json
DB ?= artifacts/lab-state.db
REPORT ?= artifacts/lab-summary.json
PROBE_URL ?= http://127.0.0.1:8088/health

.PHONY: demo validate test install clean

demo:
	PYTHONPATH=$(PYTHONPATH) $(PYTHON) -m win_netlab_foundation.cli demo --config $(CONFIG) --db $(DB) --report $(REPORT) --probe-url $(PROBE_URL)

validate:
	PYTHONPATH=$(PYTHONPATH) $(PYTHON) -m win_netlab_foundation.cli validate --config $(CONFIG)

test:
	PYTHONPATH=$(PYTHONPATH) pytest tests/python

install:
	$(PYTHON) -m pip install -e .[dev]

clean:
	rm -f $(DB) $(REPORT) artifacts/host-health.json
