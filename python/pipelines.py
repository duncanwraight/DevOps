import os
import gitlab
import arrow
import argparse
import pprint
import json
from multiprocessing import Pool
from terminaltables import AsciiTable

parser = argparse.ArgumentParser(description='Pipeline Stats')
parser.add_argument("--start_date", help="The from date")
parser.add_argument("--end_date", help="The end date")

args = parser.parse_args()

start_date = arrow.get(args.start_date)
end_date = arrow.get(args.end_date)

auth_token = os.environ['GITLAB_PRIVATE_TOKEN']

gl = gitlab.Gitlab('https://gitlab.com/', auth_token, api_version=4)
gl.auth()
pzrepo = gl.projects.get(1191)

def get_pipelines_by_date():
	print("\nRetrieving pipelines between {} and {}...".format(start_date, end_date))
	pipelines = []
	for ppage in range(1, 20):
		for pipeline in pzrepo.pipelines.list(page=ppage, per_page=100, status='success', ref='master', scope='finished'):
			pipeline_details = pzrepo.pipelines.get(pipeline.id)
			pipeline_created_at = arrow.get(pipeline_details.created_at)
			if pipeline_created_at > start_date and pipeline_created_at < end_date:
				jobs = []
				for job in pipeline.jobs.list(all=True):
					jobs.append(job)
				print("\tPipeline ID {} has {} jobs".format(pipeline.id, len(jobs)))
				if len(jobs) > 250:
					pipelines.append([pipeline_details, jobs])
				else:
					print("\t.. (discarding)")

	print("\n")
	return pipelines

pipelines = get_pipelines_by_date()
total_pipeline_duration = 0
pipeline_count = len(pipelines)

pipeline_breakdown = []

for pipeline in pipelines:
	pd = pipeline[0]
	jobs = pipeline[1]
	total_job_duration = 0
	longest_job = { 'duration': 0, 'name': '' }
	for job in jobs:
		if job.duration is not None:
			total_job_duration += job.duration
			if job.duration > longest_job['duration']:
				longest_job['duration'] = job.duration
				longest_job['name'] = "{} -> {}".format(job.stage, job.name)

	total_pipeline_duration += pd.duration

	pipeline_breakdown.append([
		pd.id,															# ID
		arrow.get(pd.created_at).format('YYYY-MM-DD HH:mm:ss'),			# Date
		round(pd.duration / 60, 2),										# Pipeline Duration
		len(jobs),														# Num Jobs
		round((total_job_duration / len(jobs)) / 60, 2),				# Avg Job Duration
		"{}\n{}".format(
			round(longest_job['duration'] / 60, 2),
			longest_job['name'])										# Longest Job
	])

avg_duration = (total_pipeline_duration / pipeline_count) / 60

pipeline_breakdown.sort(key=lambda e: e[1], reverse=True)
pipeline_breakdown.insert(0, ["ID", "Date", "Pipeline Duration", "Num Jobs", "Avg Job Duration", "Longest Job"])

summary_data = [
    ['Total Count', 'Avg Duration'],
    [pipeline_count, avg_duration]
]

print("Pipeline summary")
print(AsciiTable(summary_data).table)

print("\nPipeline/job details")
print(AsciiTable(pipeline_breakdown).table)
print("\n")
