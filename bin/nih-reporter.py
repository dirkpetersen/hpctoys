#!/usr/bin/env python3

import requests
import argparse
import re
from collections import defaultdict

'''
Query the v2 NIH Reporter API

Example:

./query-nih-reporter.py -s gonadotropin -v --terms

See the documentation at https://api.reporter.nih.gov/
'''

parser = argparse.ArgumentParser()
parser.add_argument('--verbose', '-v', action='store_true', help="Verbose")
parser.add_argument('--projects', '-p', dest='projects', help="Project numbers, comma-delimited")
parser.add_argument('--searchtext', '-s', dest='search', help="Search string using API")
parser.add_argument('--fields', dest='fields', default='projecttitle,abstracttext', help="Fields to search using API")
parser.add_argument('--fuzzy', help="Do a fuzzy text search on 'terms'")
parser.add_argument('--terms', action='store_true', help="Print out numbers of 'terms'")
parser.add_argument('--filter', help="Do a case-insensitive string filter on records, comma-delimited")
args = parser.parse_args()

def main():
    rq = ReporterQuery(args.verbose)
    # Find grants using one or more project numbers
    if args.projects:
       rq.queryByProject(args.projects)
    # Find grants by string search (default fields: title, abstract)
    if args.search:
        rq.queryByText(args.search,args.fields)
    # Filter grants
    if args.filter:
        rq.doStringFilter(args.filter)
    if args.fuzzy:
        rq.doFuzzyTermFilter(args.fuzzy)
    # Count all the terms and print()
    if args.terms:
        rq.analyzeTerms()


class ReporterQuery:

    def __init__(self, verbose):
        self.verbose = verbose
        self.url = 'https://api.reporter.nih.gov/v2/projects/search'
        self.grants = []

    def queryByText(self, searchstr, fields):
        '''
        { "criteria": { advanced_text_search: { operator: "and", search_field: "projecttitle,terms", "search_text": "brain disorder" } } }
        '''
        params = { 'criteria': { 'advanced_text_search': { 'search_field': fields, 'search_text': searchstr } } }
        resp = requests.post(self.url, json=params)
        json = resp.json()
        if json['meta']['total'] == 0:
            if self.verbose:
                print("No records for search string '{}'".format(str))
            return
        if self.verbose:
            print("Found {0} records for search string '{1}'".format(json['meta']['total'], searchstr))
        self.grants = [g for g in json['results']]

    def queryByProject(self, projects):
        '''
        { "criteria": { project_nums:["5UG1HD078437-07","5R01DK102815-05"] } }
        '''
        params = { 'criteria': { 'project_nums': projects.split(',') } }
        resp = requests.post(self.url, json=params)
        json = resp.json()
        if json['meta']['total'] == 0:
            if self.verbose:
                print("No records for search string '{}'".format(projects))
            return
        if self.verbose:
            print("Found {0} records for projects '{1}'".format(json['meta']['total'], projects))
        self.grants = [g for g in json['results']]

    def doStringFilter(self, filters):
        projects = set()
        for filter in filters.split(','):
            # regex = filter str with word boundaries
            regex = r'\b' + re.escape(filter) + r'\b'
            for grant in self.grants:
                if re.search(regex, grant['abstract'], re.IGNORECASE):
                    projects.add(grant['projectNumber'])
        if projects:
            print("Filter:{0}\tProjects:{1}".format(
                filters, projects))

    def doFuzzyTermFilter(self, searchstr):
        from fuzzywuzzy import fuzz
        for grant in self.grants:
            for term in grant['terms'].split(';'):
                if fuzz.ratio(term, searchstr) > 80:
                    print("Term:{0}\tProject:{1}".format(
                        term, grant['projectNumber']))

    def analyzeTerms(self):
        terms = defaultdict(int)
        for grant in self.grants:
            for term in re.split(r"<|>", grant['terms']):
                terms[term] += 1
        for term in terms:
            print("{0}\t{1}".format(terms[term], term))


if __name__ == "__main__":
    main()
