import os
import gitlab
import arrow
import argparse
import datetime
import time
import json
from multiprocessing import Pool
from terminaltables import AsciiTable
from colorama import Fore, Back, Style
from pztools import GoogleSheetsWrapper


### Get auth token from environment variable

auth_token = os.environ['GITLAB_PRIVATE_TOKEN']


### Parse arguments

parser = argparse.ArgumentParser(description='Pipeline Stats')
parser.add_argument("--start-date", help="The from date")
parser.add_argument("--end-date", help="The end date")
parser.add_argument("--max-jobs", help="Maximum number of jobs to list")
parser.add_argument("--pipelines", nargs="+", help="List of pipeline IDs to parse")
parser.add_argument("--jobs-to-exclude", nargs="*", help="List of job names to exclude, e.g. \"Run\"")
parser.add_argument("--statuses-to-include", nargs="*", help="List of job statuses to process, e.g. \"success\"")
parser.add_argument("--output", nargs="*", help="Locations to output analysis to - \"slack\" and/or \"google-sheets\"")
parser.add_argument("--clear", action='store_true', help="Clear Google Sheets content?")

args = parser.parse_args()

if not ((args.start_date and args.end_date) or args.pipelines):
	parser.error("You must specify either job start/end dates, or pipeline IDs")


### Set defaults and format arguments

if not args.pipelines:
	start_date = arrow.get(args.start_date)
	end_date = arrow.get(args.end_date)
	formatted_start_date = arrow.get(start_date).format('YYYY-MM-DD HH:mm:ss')
	formatted_end_date = arrow.get(end_date).format('YYYY-MM-DD HH:mm:ss')

	if args.max_jobs:
		max_jobs = args.max_jobs
	else:
		max_jobs = 5000
else:
	max_jobs = 1200

if args.jobs_to_exclude:
	jobs_to_exclude = args.jobs_to_exclude
else:
	jobs_to_exclude = ["Run",]

if args.statuses_to_include:
	statuses_to_include = args.statuses_to_include
else:
	statuses_to_include = ["success", ]


### Authenticate with Gitlab API

gl = gitlab.Gitlab('https://gitlab.com/', auth_token, api_version=4)
gl.auth()
pzrepo = gl.projects.get(1191)


### Get a list of jobs to analyse

jobs = []
durations = []

if args.pipelines:
	for pipeline_id in args.pipelines:
		print("Getting jobs from pipeline {}".format(pipeline_id))
		pipeline = pzrepo.pipelines.get(pipeline_id)
		jobs = jobs + pipeline.jobs.list(all=True)
else:
	job_list = []
	pages = range(0, int(round(int(max_jobs) / 50, 0)))
	print("\nTo run analysis on {} jobs, {} calls are required to the Gitlab API.".format(max_jobs, len(pages)))
	print("Based on historical averages, it is expected that this script will run in {}.\n".format(str(datetime.timedelta(seconds=len(pages)*5.3))))
	
	script_start_time = time.time()

	for page in pages:
		# Some time calcs for output
		
		job_start_time = time.time()
		elapsed_time = time.time() - script_start_time
		if len(durations) > 0:
			average_time = sum(durations) / len(durations)
		else:
			average_time = 0
		estimated_time = (len(pages) - page) * average_time

		print("Retrieving jobs from page {}  [elapsed: {}s / avg: {}s / eta: {}]".format(page+1, round(elapsed_time, 2), round(average_time, 2), str(datetime.timedelta(seconds=round(estimated_time)))))
		job_list = job_list + pzrepo.jobs.list(page=page, per_page=50, scope='success')

		duration = time.time() - job_start_time
		durations.append(duration)

	for job in job_list:
		created_at = arrow.get(job.created_at)
		if created_at >= start_date and created_at <= end_date:
			jobs.append(job)


### Prepare output

metrics = []

if args.pipelines:
	metrics.append({'name': 'Pipeline'})
else:
	metrics.append({'name': 'Runner'})

metrics.append({'name': 'Job'})

for metric in metrics:
	metric['durations'] = {}


### Analyse jobs

if len(jobs) > 0:
	for job in jobs:
		if job.status in statuses_to_include and job.name not in jobs_to_exclude:
			for metric in metrics:
				durations = metric['durations']

				if metric['name'] is "Pipeline":
					key = job.pipeline['id']
				elif metric['name'] is "Runner":
					if job.runner is not None:
						key = job.runner['description']
					else:
						key = 'Unknown'
				else:
					key = job.name

				if key in durations.keys():
					durations[key]['duration'] += job.duration
					durations[key]['count'] = durations[key]['count'] + 1
					if job.duration > durations[key]['max']:
						durations[key]['max'] = job.duration
				else:
					durations[key] = {}
					durations[key]['duration'] = job.duration
					durations[key]['max'] = job.duration
					durations[key]['count'] = 1


### Sanitize output

def get_output_durations(durations_dict):
	return_list = []
	for key, value in durations_dict.items():
		duration = value['duration'] / value['count']
		return_list.append([key, round(duration / 60, 2), round(value['max'] / 60, 2)])

	return return_list


### Google Sheets output
if args.output:
	if args.clear:
		formatted_jobs = [['ID', 'Name', 'Pipeline ID', 'Runner', 'Duration', 'Started', 'Finished', 'URL']]
	else:
		formatted_jobs = []

	if "google-sheets" in args.output:
		SHEETS = GoogleSheetsWrapper('./auth', '1pp1SMLRsJ1Yn9SyhNPjMlAgs2Lr-gAvIaej3juWV7ws')
		
		for job in jobs:
			if job.runner is not None:
				runner = job.runner['description'].replace("runner ", "").replace("std ","")
			else:
				# This happens if the runner in question has been terminated by time stats are run
				runner = 'Unknown'

			formatted_jobs.append([
				job.id,
				job.name,
				job.pipeline['id'],
				runner,
				round(job.duration, 2),
				arrow.get(job.created_at).format('YYYY-MM-DD HH:mm:ss'),
				arrow.get(job.finished_at).format('YYYY-MM-DD HH:mm:ss'),
				job.web_url])
		
		if args.clear:
			SHEETS.populate_sheet('JobData', formatted_jobs)
		else:
			SHEETS.append_content('JobData', formatted_jobs)


### Output analysis

if args.pipelines:
	print("\n{}=== {} jobs have run on pipeline IDs {} ==={}".format(Fore.RED, len(jobs), ", ".join(args.pipelines), Style.RESET_ALL))
else:
	print("\n{}=== {} jobs have run between {} and {} ==={}".format(Fore.RED, len(jobs), formatted_start_date, formatted_end_date, Style.RESET_ALL))

for metric in metrics:
	print("\n{}Durations by {}{}".format(Fore.GREEN, metric['name'].lower(), Style.RESET_ALL))
	jobs = get_output_durations(metric['durations'])
	jobs.sort(key=lambda e: e[1], reverse=True)
	jobs.insert(0, [metric['name'], "Average duration", "Max duration"])
	if metric['name'] is "Job":
		jobs = jobs[:20]
	print(AsciiTable(jobs).table)
