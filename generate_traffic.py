#!/usr/bin/python

import random
import json
import string

import sys

priorities = ["critical", "high", "medium", "low"]

def message_generator():
	chars = string.ascii_uppercase + string.ascii_lowercase + string.digits
	return ''.join(random.choice(chars) for _ in xrange(3, random.randint(5, 20)))

def create_message():
	m = dict()
	m['priority'] = random.choice(priorities)
	m['element'] = message_generator()
	return json.dumps(m)

def create_query():
	if random.choice([0, 1, 2, 3]):
		return "http://localhost:8080/"
	else:
		return "http://localhost:8080/ POST " + create_message()

if __name__ == '__main__':
	f = sys.argv[1]
	lines = int(sys.argv[2])
	with open(f, 'w') as fl:
		for line in xrange(lines):
			fl.write(create_query() + '\n')

