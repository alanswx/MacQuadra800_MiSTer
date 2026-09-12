# Model routing

Use gpt-6-astra for CPU architecture, RTL/code changes, and failure diagnosis.
Use gpt-5.6-luna for established regression/build procedures, MiSTer GUI
navigation, Speedometer runs, and evidence collection. Read
docs/AGENT_TESTING_WORKFLOW.md before delegating tests.

The user explicitly authorizes delegation with this model split. Give test
agents bounded tasks and concise handoffs rather than the full conversation.
Only one agent may control the FPGA or guest input at a time. An active test
must transfer ownership explicitly before another agent touches the machine.

Do not silently substitute another model if the requested model is unavailable;
report the limitation. These instructions route delegated work; they do not
change the current conversation model automatically.

# Hardware lifecycle guard

Test agents must use `bash scripts/cpu_benchmark_core.sh` for deployment and
cleanup. They must not construct raw core-load commands, load Main as a core,
overwrite disks directly, or restart/reprogram/reboot Main/FPGA themselves.
If the guard fails, stop hardware actions and return evidence to Astra.
Guest keyboard/screenshot testing remains allowed under exclusive ownership.

# Tool completion is not process completion

An outer functions.exec/wait message saying Script completed may contain an
exec_command result with a live session_id. Inspect the nested result. Poll
that session using write_stdin until it returns an actual exit_code. Likewise
resume an outer running cell with functions.wait. Never restore/reload while
a navigation or benchmark command is still running. Partial output is not a
failure or completion signal; report exact exit status and stderr on failure.
