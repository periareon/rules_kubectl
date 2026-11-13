// The `bazel run` launcher for kubectl.
//
// It locates kubectl through runfiles, changes to the directory `bazel run`
// was invoked from (`BUILD_WORKING_DIRECTORY`) and hands over to kubectl, so
// relative paths in arguments such as `-f ./deploy.yaml` resolve the way they
// would for a locally installed kubectl. Arguments, environment and exit
// status pass through unchanged.
package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// kubectlRlocationpath is the rlocationpath of the kubectl binary. It is set
// at link time by `kubectl_launcher` from the toolchain's
// `KUBECTL_RLOCATIONPATH` make variable.
var kubectlRlocationpath string

func main() {
	if kubectlRlocationpath == "" {
		fatalf("launcher was built without the rlocationpath of kubectl")
	}

	kubectl, err := runfiles.Rlocation(kubectlRlocationpath)
	if err != nil {
		fatalf("failed to locate %s in runfiles: %v", kubectlRlocationpath, err)
	}

	// Resolve before changing directory in case the runfiles path is relative.
	kubectl, err = filepath.Abs(kubectl)
	if err != nil {
		fatalf("failed to resolve %s: %v", kubectl, err)
	}

	if dir := os.Getenv("BUILD_WORKING_DIRECTORY"); dir != "" {
		if err := os.Chdir(dir); err != nil {
			fatalf("failed to change to BUILD_WORKING_DIRECTORY: %v", err)
		}
	}

	if err := run(kubectl, os.Args[1:]); err != nil {
		fatalf("failed to run %s: %v", kubectl, err)
	}
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "kubectl launcher: "+format+"\n", args...)
	os.Exit(1)
}
