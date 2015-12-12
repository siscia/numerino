#!/usr/bin/python

import random
import json
import string

import sys

import requests

queues = [["critical", "high", "medium", "low"], 
          [x for x in xrange(10, 1, -1)], 
          ["super criticial", "critical", "danger", "fix now", "to do", "nice to have", "who cares..."],
          [x for x in xrange(15, 0, -3)]]


class PersistentQueue(object):
    def __init__(self, queue, f, lock):
        self.queue = queue
        self.ID = ''
        self.lock = lock
        self.f = f

    def get_priority(self):
        return random.choice(self.queue)

    def host(self):
        return "http://localhost:4000/persistent/"

    def request_queue(self):
        q = {"type" : "persistent", "priorities" : self.queue}
        r = requests.post(self.host(), data = json.dumps(q),
                                       headers = {'content-type' : 'application/json'})
        self.ID = str(r.json()['name'])
        return r.json()

    def url(self):
        return self.host() + self.ID
    
    def make_get(self):
        return self.url

    def make_post(self):
        query = {}
        query['priority'] = self.get_priority()
        query['element'] = message_generator()
        return self.url() + " POST " + json.dumps(query)
    
    def write_request(self):
        if random.choice([0, 1, 2]):
            command = self.make_post()
        else:
            command = self.make_get()
        self.lock.acquire()
        self.f.write(command)
        self.lock.release()


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
		return "http://localhost:8080/ POST " + create_message()
	else:
		return "http://localhost:8080/"

if __name__ == '__main__':
	f = sys.argv[1]
	lines = int(sys.argv[2])
	with open(f, 'w') as fl:
		for line in xrange(lines):
			fl.write(create_query() + '\n')

