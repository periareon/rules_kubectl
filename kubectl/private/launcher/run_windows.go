package main

import (
	"errors"
	"os"
	"os/exec"
	"os/signal"
)

// run starts kubectl as a child process and exits with its status.
func run(kubectl string, args []string) error {
	// The console delivers Ctrl+C to the whole process group; let kubectl
	// decide how to handle it and report its exit status.
	signal.Ignore(os.Interrupt)

	cmd := exec.Command(kubectl, args...)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	err := cmd.Run()
	var exitErr *exec.ExitError
	if errors.As(err, &exitErr) {
		os.Exit(exitErr.ExitCode())
	}
	return err
}
