# Agentic-Retail-Assistant
# Agentic Retail Assistant

**Agentic Retail Assistant** is an agentic AI project focused on retail operations and customer shopping assistance.
It was built using **IBM watsonx Orchestrate** and integrated with **Confluent**, with the goal of exploring how multiple AI agents can coordinate structured workflows in a business environment.

## Overview

This project implements a multi-agent assistant designed to support common retail and customer service workflows, such as:

* Product search
* SKU availability by store branch
* Store information
* Customer shopping assistance
* Workflow orchestration between multiple specialized agents

The main objective of the project is to demonstrate how agentic AI can be used beyond simple conversational interfaces, enabling task automation, structured decision-making and reliable execution of business processes.

## Technologies Used

* IBM watsonx Orchestrate
* Confluent
* YAML-based agent definitions
* Agentic AI workflows
* Git and GitHub

## Project Structure

```bash
Agentic-Retail-Assistant/
├── confluent_agent/
│   ├── Customer_Shopping_Assistant.yaml
│   ├── Product_Search_Agent.yaml
│   ├── SKU_Availability_Agent.yaml
│   └── Store_Information_Agent.yaml
├── README.md
└── LICENSE
```

> Note: The exact file structure may vary depending on the local configuration and exported agent files.

## Agents

### Customer Shopping Assistant

Main assistant responsible for interacting with the user and coordinating shopping-related requests.

### Product Search Agent

Agent designed to help search for products based on customer needs, product categories or specific queries.

### SKU Availability Agent

Agent focused on checking SKU availability across different store branches.

### Store Information Agent

Agent responsible for providing information about stores, branches and related customer service details.

## Importing Agents

Agents can be imported into IBM watsonx Orchestrate using the following command structure:

```bash
orchestrate agents import -f confluent_agent/Customer_Shopping_Assistant.yaml
```

The same approach can be used for the remaining agent definition files.

## Testing

The agents were tested directly through the IBM watsonx Orchestrate interface using different retail-related scenarios, including product search, SKU availability checks and customer shopping assistance flows.

## Purpose

This project was developed as a portfolio project to explore:

* Agentic AI applied to real-world business processes
* Multi-agent workflow design
* Retail operations automation
* Integration between IBM watsonx Orchestrate and Confluent
* Practical use cases of AI assistants in enterprise environments

## Key Learnings

Through this project, I gained hands-on experience with:

* Defining and importing AI agents
* Structuring multi-agent workflows
* Testing agent behavior through practical scenarios
* Understanding how agentic systems can support operational processes
* Organizing an AI project for technical documentation and portfolio presentation

## Repository

GitHub repository:
https://github.com/acostatomas/Agentic-Retail-Assistant

## Author

**Tomás Acosta**
Computer Engineering student at UCEMA
GitHub: [@acostatomas](https://github.com/acostatomas)
