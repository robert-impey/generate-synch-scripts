// Generates synch scripts for running rsync between two directories
package main

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strings"
)

const allDirsScriptName = "_all.sh"
const cmdLineTemplate = "%v %v/%v/ %v/%v"

type ScriptsInfo struct {
	dir, synch, src, dst string
	dirs                 []string
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
	defer gssFile.Close()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to open %v - %v\n", gssFileName, err)
		return scriptsInfo, err
	}
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
	dirs := make([]string, 0)
	for input.Scan() {
		dir := strings.Trim(input.Text(), " /")
		if len(dir) > 0 {
			dirs = append(dirs, dir)
		}
	}
	scriptsInfo.dirs = dirs

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

	scriptFileName := filepath.Join(scriptsInfo.dir, allDirsScriptName)
	scriptContents := "#!/bin/bash\n# AUTOGEN'D - DO NOT EDIT!\n\n"

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
	err := ioutil.WriteFile(scriptFileName, []byte(scriptContents), 0x755)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Unable to write script to %v - %v\n", scriptFileName, err)
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
