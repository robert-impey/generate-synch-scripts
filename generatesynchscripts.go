// Generates synch scripts for running rsync between two directories
package main

import (
	"bufio"
	"errors"
	"fmt"
	mapset "github.com/deckarep/golang-set/v2"
	"os"
	"os/user"
	"path"
	"path/filepath"
	"sort"
	"strings"
)

const cmdLineTemplate = "%v %v/%v/ %v/%v"

type ScriptsInfo struct {
	name, dir, synch, src, dst string
	dirs                       []string
}

func main() {
	gssFiles := make([]string, 0)

	for _, arg := range os.Args[1:] {
		_, err := os.Stat(arg)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to process %v - %v\n", arg, err)
			continue
		}
		gssFiles = append(gssFiles, arg)
	}

	for _, gssFile := range gssFiles {
		err := generateSynchScripts(gssFile)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unable to generate the scripts for %v - %v\n", gssFile, err)
			continue
		}
	}
}

func generateSynchScripts(gssFile string) error {
	fmt.Printf("Generating synch scripts for %v\n", gssFile)

	scriptInfo, err := parseGSSFile(gssFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to parse %v - %v\n", gssFile, err)
		return err
	}

	if err := writeAllDirs(scriptInfo); err != nil {
		fmt.Fprintf(os.Stderr, "Unable to write all dirs script for %v - %v\n", gssFile, err)
		return err
	}
	return nil
}

func parseGSSFile(gssFileName string) (*ScriptsInfo, error) {
	scriptsInfo := new(ScriptsInfo)

	base := filepath.Base(gssFileName)

	scriptsInfo.name = strings.TrimSuffix(base, path.Ext(base))

	// Script directory
	dir := filepath.Dir(gssFileName)
	absDir, err := filepath.Abs(dir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to find the absolute directory name for %v\n", dir)
		return scriptsInfo, err
	}
	scriptsInfo.dir = absDir

	// Read the file
	gssFile, err := os.Open(gssFileName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to open %v - %v\n", gssFileName, err)
		return scriptsInfo, err
	}
	defer gssFile.Close()
	input := bufio.NewScanner(gssFile)

	// Get the script root
	input.Scan()
	scriptsInfo.synch = input.Text()

	// Get the src and the dst
	input.Scan()
	scriptsInfo.src = input.Text()
	input.Scan()
	scriptsInfo.dst = input.Text()

	// Skip the blank line
	input.Scan()

	// Get the list of directories
	dirs := mapset.NewSet[string]()
	for input.Scan() {
		dir := strings.Trim(input.Text(), " /")
		if len(dir) > 0 {
			dirs.Add(dir)
		}
	}
	dirsSlice := dirs.ToSlice()
	sort.Strings(dirsSlice)
	scriptsInfo.dirs = dirsSlice

	return scriptsInfo, nil
}

func writeAllDirs(scriptsInfo *ScriptsInfo) error {
	fmt.Printf("Generating scripts in %v\n", scriptsInfo.dir)
	fmt.Printf("Synch root: %v\n", scriptsInfo.synch)
	fmt.Printf("Source: %v\n", scriptsInfo.src)
	fmt.Printf("Destination: %v\n", scriptsInfo.dst)
	fmt.Println("Directories to synch:")
	for _, dir := range scriptsInfo.dirs {
		fmt.Println(dir)
	}
	fmt.Println()

	user, err := user.Current()
	if err != nil {
		fmt.Fprint(os.Stderr, err.Error())
		return err
	}

	autoGenDir := filepath.Join(user.HomeDir, "autogen", "synch")

	if _, err := os.Stat(autoGenDir); errors.Is(err, os.ErrNotExist) {
		err := os.MkdirAll(autoGenDir, os.ModePerm)
		if err != nil {
			fmt.Fprint(os.Stderr, err.Error())
			return err
		}
	}

	scriptName := fmt.Sprintf("%s.sh", scriptsInfo.name)
	scriptFileName := filepath.Join(autoGenDir, scriptName)

	if _, err := os.Stat(scriptFileName); err == nil {
		fmt.Printf("%v exists - Deleting...\n", scriptFileName)
		err := os.Remove(scriptFileName)
		if err != nil {
			fmt.Fprint(os.Stderr, err.Error())
		}
	}

	scriptContents := "#!/bin/bash\n# AUTOGEN'D - DO NOT EDIT!\n\n"

	scriptContents += "date\n\n"

	for _, dir := range scriptsInfo.dirs {
		to := getCmdLine(
			scriptsInfo.synch,
			dir,
			scriptsInfo.src,
			scriptsInfo.dst)
		scriptContents += getEchoLine(to) + "\n"
		scriptContents += to + "\n"

		from := getCmdLine(
			scriptsInfo.synch,
			dir,
			scriptsInfo.dst,
			scriptsInfo.src)
		scriptContents += getEchoLine(from) + "\n"
		scriptContents += from + "\n"

		scriptContents += "\n"
	}

	scriptContents += "\ndate\n"

	err = os.WriteFile(scriptFileName, []byte(scriptContents), 0x755)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to write script to %v - %v\n", scriptFileName, err)
	}

	if len(scriptsInfo.dirs) > 1 {
		fileDir := filepath.Join(autoGenDir, scriptsInfo.name)

		if _, err := os.Stat(fileDir); errors.Is(err, os.ErrNotExist) {
			err := os.MkdirAll(fileDir, os.ModePerm)
			if err != nil {
				fmt.Fprint(os.Stderr, err.Error())
				return err
			}
		}

		for _, dir := range scriptsInfo.dirs {
			scriptName := fmt.Sprintf("%s.sh", dir)
			scriptFileName := filepath.Join(fileDir, scriptName)

			if _, err := os.Stat(scriptFileName); err == nil {
				fmt.Printf("%v exists - Deleting...\n", scriptFileName)
				err := os.Remove(scriptFileName)
				if err != nil {
					fmt.Fprint(os.Stderr, err.Error())
				}
			}

			scriptContents := "#!/bin/bash\n# AUTOGEN'D - DO NOT EDIT!\n\n"

			scriptContents += "date\n\n"

			to := getCmdLine(
				scriptsInfo.synch,
				dir,
				scriptsInfo.src,
				scriptsInfo.dst)
			scriptContents += getEchoLine(to) + "\n"
			scriptContents += to + "\n"

			from := getCmdLine(
				scriptsInfo.synch,
				dir,
				scriptsInfo.dst,
				scriptsInfo.src)
			scriptContents += getEchoLine(from) + "\n"
			scriptContents += from + "\n"

			scriptContents += "\n"

			scriptContents += "\ndate\n"

			err = os.WriteFile(scriptFileName, []byte(scriptContents), 0x755)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Unable to write script to %v - %v\n", scriptFileName, err)
			}
		}
	}

	return nil
}

func getCmdLine(synchRoot, dir, src, dst string) string {
	return fmt.Sprintf(
		cmdLineTemplate,
		synchRoot,
		src, dir,
		dst, dir)
}

func getEchoLine(cmd string) string {
	return fmt.Sprintf("echo '%s'", cmd)
}
