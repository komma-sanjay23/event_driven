[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)]()
[![Code Quality](https://img.shields.io/badge/code%20quality-A-green)]()
[![Python](https://img.shields.io/badge/python-3.11+-blue)]()
[![AWS](https://img.shields.io/badge/AWS-S3%20%7C%20Lambda%20%7C%20Step%20Functions%20%7C%20DynamoDB-orange)]()
[![Terraform](https://img.shields.io/badge/IaC-Terraform%20%7C%20AWS-blueviolet)]()




## Table of Contents

1. [Overview](#overview)
2. [Services Used](#services-used)
3. [Architecture](#architecture-pipeline-flow)
4. [Project Structure](#project-structure)
5. [Setup Instructions](#setup-instructions)
6. [Monitoring & Alerts](#monitoring-and-alerts)
7. [Future Improvements](#future-improvements)
8. [Resources & References](#resources--references)



## <a name="overview"></a>Overview

This project builds an event-driven data pipeline to track and process user activity.  
Events are collected into Amazon S3, orchestrated via Step Functions, processed with AWS Lambda (Python), persisted into DynamoDB, and monitored using CloudWatch.  
All infrastructure is managed through Terraform, ensuring reproducibility and no manual console steps.

**Key Features:**

- **Fully Event-Driven Architecture**  
  New data arriving in S3 automatically triggers the pipeline without manual intervention.

- **Automated Orchestration with Step Functions**  
  State machine manages the flow from ingestion → transform → load, with retries and error handling.

- **Serverless Processing with AWS Lambda**  
  Lightweight, scalable Python functions for data collection, transformation, and loading.

- **Scalable Storage with DynamoDB**  
  Stores processed events with flexible schema and on-demand scaling.

- **End-to-End Infrastructure as Code**  
  Entire stack (S3, IAM, Lambdas, Step Functions, DynamoDB, CloudWatch) provisioned using Terraform.

- **Data Quality Safeguards**  
  JSON validation, schema checks for `user_id`, `action`, `event_ts`, and error handling for malformed records.

- **Monitoring & Alerts**  
  CloudWatch logs for each component and alarms for Lambda errors or failed executions.

- **Test Data Simulation**  
  Built-in simulator to generate synthetic JSONL events (configurable for small smoke tests or large-scale loads like 5GB).

- **Error Handling & Recovery**  
  Step Functions retry policy with exponential backoff, plus graceful handling of bad records in Lambdas.

- **Easily Extensible**  
  Ready hooks for adding a Transform step, schema evolution, or analytical integrations (Athena/Redshift).



## <a name="services-used"></a>Services Used

- **Amazon S3** → Raw event ingestion (JSONL files, `ingest/` prefix).
- **AWS Lambda** → Collector, Transform, and Load functions.
- **AWS Step Functions** → Orchestration of processing steps.
- **Amazon DynamoDB** → Processed event storage.
- **Amazon CloudWatch** → Logs, metrics, and alarms.
- **AWS IAM** → Role-based access control.
- **Terraform** → Infrastructure as Code.
- **Python** → Event simulator, Lambda logic.



## <a name="architecture-pipeline-flow"></a>Architecture Pipeline Flow

![Architecture Diagram](images/Architecture.png)

### Data Ingestion
- Python simulator generates user-activity events (JSONL).
- Files uploaded to Amazon S3 under `ingest/` prefix.

### Orchestration
- S3 events trigger Collector Lambda.
- Collector starts a Step Functions execution with S3 bucket/key details.

### Processing
- Step Functions invoke Load Lambda.
- Load Lambda validates records and stores them in DynamoDB.
- Invalid/malformed records are skipped and logged.

### Monitoring
- CloudWatch tracks Lambda logs, Step Functions executions, and error metrics.
- Alarms notify on failed executions or Lambda errors.

### Error Handling
- Step Functions retries failed tasks with exponential backoff.
- DynamoDB duplicate writes prevented by composite key (`user_id`, `event_ts`).



## <a name="project-structure"></a>Project Structure

```
Event-Driven-Pipeline/
├── lambdas/
│   ├── collector.py        
│   └── processor.py        
├── simulator/
│   └── generator.py        
├── terraform/
│   ├── main.tf             
│   ├── lambda.tf           
│   ├── stepfunctions.tf    
│   ├── dynamodb.tf         
│   ├── variables.tf        
│   └── outputs.tf          
└── test_event.jsonl        
```



## <a name="setup-instructions"></a>Setup Instructions

### Prerequisites

- AWS account with permissions for S3, stepfunction, Lambda, DynamoDB, IAM, and CloudWatch.
- Terraform installed.
- Python 3.11+ installed (for simulator).

### Setup Steps

1. **Clone the repository**
    ```sh
    git clone <your-repo-url>
    cd event-driven-pipeline
    ```
2. **Deploy AWS infrastructure**
    ```sh
    terraform init
    terraform plan
    terraform apply
    ```
3. **Running the Simulator**
    ```sh
    python simulator/generator.py
    ```



## <a name="monitoring-and-alerts"></a>Monitoring and Alerts

### CloudWatch Logs & Metrics

- All Lambda functions and Step Functions executions are tracked in CloudWatch for errors, durations, and invocation counts.


### CloudWatch Alarms

- Alerts are triggered when Lambda errors or Step Functions execution failures exceed thresholds.


### Step Functions Monitoring

- Execution history and visual workflow graphs in Step Functions make it easy to trace failed runs, identify the exact state causing errors, and verify successful pipeline executions.



## <a name="future-improvements"></a>Future Improvements

- **Schema Validation** – Enforce strict event schemas using AWS Glue Schema Registry or JSON validation.
- **Dead-Letter Queue (DLQ)** – Capture failed records for troubleshooting and reprocessing.
- **Security Enhancements** – Add KMS encryption, stricter IAM policies, and VPC controls for Lambdas.
- **Analytics Layer** – Connect DynamoDB/S3 data to Athena, Redshift, or QuickSight for dashboards.



## <a name="resources--references"></a>Resources & References

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS Step Functions Documentation](https://docs.aws.amazon.com/step-functions/)
- [AWS DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [AWS CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Python Official Documentation](https://docs.python.org/3/)
- [Boto3 AWS SDK for Python](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [Data Engineering on AWS](https://aws.amazon.com/big-data/datalakes-and-analytics/)
- [Serverless Architectures](https://martinfowler.com/articles/serverless.html)
