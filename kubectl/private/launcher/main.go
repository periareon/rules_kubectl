// The launcher behind `kubectl_binary` and `bazel run @kubectl`.
//
// It reads a configuration naming the kubectl binary, arguments and
// environment, resolves every runfiles reference in it to an absolute path,
// changes to the directory `bazel run` was invoked from
// (`BUILD_WORKING_DIRECTORY`) and hands over to kubectl. Arguments given on
// the command line are appended, and the exit status passes through.
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/bazelbuild/rules_go/go/runfiles"
)

// configRlocationpath is the rlocationpath of the configuration file. It is
// set at link time by `kubectl_binary`.
var configRlocationpath string

// segment is one piece of an argument or environment value: either literal
// text or a runfiles path to resolve.
type segment struct {
	Text    string `json:"text"`
	Runfile string `json:"runfile"`
}

type config struct {
	Kubectl string               `json:"kubectl"`
	Args    [][]segment          `json:"args"`
	Env     map[string][]segment `json:"env"`
}

func main() {
	if configRlocationpath == "" {
		fatalf("launcher was built without a configuration")
	}

	r, err := runfiles.New()
	if err != nil {
		fatalf("failed to locate runfiles: %v", err)
	}

	cfg, err := loadConfig(r)
	if err != nil {
		fatalf("%v", err)
	}

	kubectl, err := resolve(r, cfg.Kubectl)
	if err != nil {
		fatalf("failed to locate kubectl: %v", err)
	}

	args := make([]string, 0, len(cfg.Args)+len(os.Args)-1)
	for _, segments := range cfg.Args {
		arg, err := render(r, segments)
		if err != nil {
			fatalf("failed to resolve argument: %v", err)
		}
		args = append(args, arg)
	}
	args = append(args, os.Args[1:]...)

	for key, segments := range cfg.Env {
		value, err := render(r, segments)
		if err != nil {
			fatalf("failed to resolve %s: %v", key, err)
		}
		if err := os.Setenv(key, value); err != nil {
			fatalf("failed to set %s: %v", key, err)
		}
	}

	if dir := os.Getenv("BUILD_WORKING_DIRECTORY"); dir != "" {
		if err := os.Chdir(dir); err != nil {
			fatalf("failed to change to BUILD_WORKING_DIRECTORY: %v", err)
		}
	}

	if err := run(kubectl, args); err != nil {
		fatalf("failed to run %s: %v", kubectl, err)
	}
}

func loadConfig(r *runfiles.Runfiles) (*config, error) {
	path, err := resolve(r, configRlocationpath)
	if err != nil {
		return nil, fmt.Errorf("failed to locate the launcher configuration: %w", err)
	}
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read the launcher configuration: %w", err)
	}
	var cfg config
	if err := json.Unmarshal(content, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse %s: %w", path, err)
	}
	return &cfg, nil
}

// resolve returns the absolute path of a runfile. Paths are made absolute
// before the working directory changes.
func resolve(r *runfiles.Runfiles, rlocationpath string) (string, error) {
	path, err := r.Rlocation(rlocationpath)
	if err != nil {
		return "", fmt.Errorf("%s: %w", rlocationpath, err)
	}
	return filepath.Abs(path)
}

func render(r *runfiles.Runfiles, segments []segment) (string, error) {
	var value strings.Builder
	for _, s := range segments {
		if s.Runfile == "" {
			value.WriteString(s.Text)
			continue
		}
		path, err := resolve(r, s.Runfile)
		if err != nil {
			return "", err
		}
		value.WriteString(path)
	}
	return value.String(), nil
}

func fatalf(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "kubectl launcher: "+format+"\n", args...)
	os.Exit(1)
}
