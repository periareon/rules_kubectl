//go:build !windows

package main

import (
	"os"
	"syscall"
)

// run replaces the current process with kubectl.
func run(kubectl string, args []string) error {
	return syscall.Exec(kubectl, append([]string{kubectl}, args...), os.Environ())
}
