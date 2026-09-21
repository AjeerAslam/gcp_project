variable "catalog" {
  type        = string
  description = "Unity Catalog catalog for the pipeline tables."
}

variable "environment" {
  type        = string
  description = "Environment name used in schema and job names."
}

variable "landing_uri" {
  type        = string
  description = "GCS URI containing the XML landing files."
}

variable "notebook_path" {
  type        = string
  description = "Databricks workspace directory for the notebooks."
}

variable "notebook_source_root" {
  type        = string
  description = "Local directory containing the Databricks notebook source files."
}