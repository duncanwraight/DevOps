# Logstash pipeline filter replacement

When diagnosing problems/adding additional functionality to our Logstash server, the process can be
quite arduous and menial.

This Playbook automates the process, allowing you to make local changes to the file then have the
Playbook do the rest, e.g. copy the file then restart the Logstash service and wait for it to come
back up before spitting out some logs.
