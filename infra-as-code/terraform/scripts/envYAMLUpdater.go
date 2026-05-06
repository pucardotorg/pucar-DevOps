package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
)

func main() {
	// Read the Terraform output from stdin
	input, err := ioutil.ReadAll(os.Stdin)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading input: %v\n", err)
		os.Exit(1)
	}

	// Define struct to unmarshal JSON data
	var tfOutput map[string]struct {
		Value string `json:"value"`
	}

	// Unmarshal the JSON output into the struct
	if err := json.Unmarshal(input, &tfOutput); err != nil {
		fmt.Fprintf(os.Stderr, "Error parsing JSON: %v\n", err)
		os.Exit(1)
	}

	// Read the YAML file
	yamlFile, err := ioutil.ReadFile("../../../deploy-as-code/charts/environments/env.yaml")
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading YAML file: %v\n", err)
		os.Exit(1)
	}

	// Replace placeholders with values from Terraform output
	output := string(yamlFile)
	for key, value := range tfOutput {
		placeholder := fmt.Sprintf("<%s>", key)
		output = strings.ReplaceAll(output, placeholder, value.Value)
	}

	// Write the updated YAML to file
	yamlPath := "../../../deploy-as-code/charts/environments/env.yaml"
	if err := ioutil.WriteFile(yamlPath, []byte(output), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing YAML file: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("YAML successfully written to file:", yamlPath)

	// Create kubeConfig file
	/* kubeConfigPath := "../../../deploy-as-code/deployer/kubeConfig"
	kubeConfigFile, err := os.Create(kubeConfigPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating kubeConfig file: %v\n", err)
		os.Exit(1)
	}
	defer kubeConfigFile.Close()

	// Write kubeConfigString to kubeConfig file
	kubeConfigString := tfOutput["KubeConfig"].Value
	if _, err := kubeConfigFile.WriteString(kubeConfigString); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing to kubeConfig file: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("KubeConfig successfully written to file:", kubeConfigPath) */

	// Print command to set KUBECONFIG
	/* fmt.Println("Please run the following command to set the kubeConfig:")
	fmt.Printf("\texport KUBECONFIG=\"%s\"\n", kubeConfigPath) */
}
