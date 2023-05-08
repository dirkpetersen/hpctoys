#!/usr/bin/env python3

import sys,requests, argparse, re, datetime
from collections import defaultdict

'''
Query the v2 NIH Reporter API

Example:

./query-nih-reporter.py -v --org "Stanford" --years 5 
./query-nih-reporter.py -v --org "Stanford" --years 2022,2023
./query-nih-reporter.py -v --org "Stanford" --active
./query-nih-reporter.py -v -s "Lymphoma" --terms

See the documentation at https://api.reporter.nih.gov/

based on https://gist.github.com/bosborne/8efbd21ffbe3dc8d057d80539114ab07

'''

def list_str(values):
    # a parser type that converts a string list to list
    if not values:
        return []
    elif values.isnumeric() and int(values) < 10:
        y1 = datetime.datetime.today().year
        return [y1 - i for i in range(int(values))]        
    return values.split(',')

parser = argparse.ArgumentParser()
parser.add_argument('--verbose', '-v', action='store_true', help="Verbose")
parser.add_argument('--projects', '-p', dest='projects', help="Project numbers, comma-delimited")
parser.add_argument('--searchtext', '-s', dest='search', help="Search string using API")
parser.add_argument('--org', '-o', dest='org', help="Search string using API")
parser.add_argument('--years', '-y', dest='years', default='', type=list_str, help="Limit to fiscal years, e.g. 2019,2020,2021")
parser.add_argument('--fields', dest='fields', default='projecttitle,abstracttext', help="Fields to search using API")
parser.add_argument('--fuzzy', help="Do a fuzzy text search on 'terms'")
parser.add_argument('--terms', action='store_true', help="Print out numbers of 'terms'")
parser.add_argument('--active', action='store_true', help="show only active")
parser.add_argument('--results', action='store_true', help="show results")
parser.add_argument('--filter', help="Do a case-insensitive string filter on records, comma-delimited")
args = parser.parse_args()

def main():
    rq = ReporterQuery(args.verbose, args.active, args.years)
    # Find grants using one or more project numbers
    if args.projects:
       rq.queryByProject(args.projects)
    # Find grants by string search (default fields: title, abstract)
    if args.search:
        rq.queryByText(args.search,args.fields)
    if args.org:
        rq.queryByOrg(args.org)
    # Filter grants
    if args.filter:
        rq.doStringFilter(args.filter)
    if args.fuzzy:
        rq.doFuzzyTermFilter(args.fuzzy)
    # Count all the terms and print()
    if args.terms:
        rq.analyzeTerms()

    #if args.results:
    rq.showResults()

class ReporterQuery:

    def __init__(self, verbose, active, years):
        self.verbose = verbose
        self.active = active
        self.years = years
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
                print("No records for search string '{}'".format(projects),file=sys.stderr)
            return
        if self.verbose:
            print("Found {0} records for projects '{1}'".format(json['meta']['total'], projects),file=sys.stderr)
        self.grants = [g for g in json['results']]


    def queryByOrg(self, org):
        '''
        { 'criteria': { 'include_active_projects': True, 'fiscal_years': [2019,2020], 'org_names': ['Stanford'] } }
        '''
        offset = 0
        limit = 500        
        total = 1
        self.grants = []
        while total > len(self.grants):
            if org.lower() == 'all':
                params = { 'offset': offset, 'limit': limit, 'criteria': {
                               'include_active_projects': self.active, 'fiscal_years': self.years 
                         }}
            else:
                params = { 'offset': offset, 'limit': limit, 'criteria': { 
                               'include_active_projects': self.active, 'fiscal_years': self.years, 'org_names': [org] 
                         }}
            resp = requests.post(self.url, json=params)
            if resp.status_code != 200: 
                print ("Error {0} connecting to NIH reporter, Reason: {1}".format(resp.status_code, resp.reason),file=sys.stderr)
                return
            json = resp.json()
            total = json['meta']['total']
            if total == 0:
                if self.verbose:
                    print("No records for organization '{}'".format(org),file=sys.stderr)
                return            
            self.grants += [g for g in json['results']]
            if self.verbose:
                print("{0} records off {1} total returned ...".format(offset,total),file=sys.stderr)
            offset+=limit            
            if offset == 15000:
               offset == 14999
            elif offset > 15000:
                break
            
        if self.verbose:
            print("Found {0} records for organization '{1}'".format(total, org),file=sys.stderr)

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
            for term in re.split(r"<|>", str(grant['terms'])):
                terms[term] += 1
        for term in terms:
            print("{0}\t{1}".format(terms[term], term))


    def showResults(self):
        print('project_num, fiscal_year, org_name, profile_id(PI), last_name, first_name, middle_name, full_name, direct_cost_amt, indirect_cost_amt, fa_rate, award_amount')
        total_awards=0
        total_indirects=0
        PIs={}
        for g in self.grants:
            #print(g)
            line = '"{0}",{1},"{2}",'.format(
                 str(g['project_num']),
                 str(g['fiscal_year']),
                 str(g['organization']['org_name'].encode('utf-8'),'utf-8') 
                 )
            for p in g['principal_investigators']:
                if p['is_contact_pi']:
                    l=str(p['last_name'].encode('utf-8'),'utf-8').title()
                    f=str(p['first_name'].encode('utf-8'),'utf-8').title()
                    m=str(p['middle_name'].encode('utf-8'),'utf-8').title()                   
                    line += '{0},"{1}","{2}","{3}","{4}"'.format(
                      p['profile_id'],l,f,m,'{0}, {1} {2}'.format(l,f,m).strip())
                    PIs[l+f+m]=1
                    
            rate=0
            if g['direct_cost_amt'] and g['indirect_cost_amt']:
                rate=round(g['indirect_cost_amt']/g['direct_cost_amt'],3)

            if not g['award_amount']:
                 g['award_amount'] = 0
           
            line='{0},{1},{2},{3},{4}'.format(line,
                      g['direct_cost_amt'],
                      g['indirect_cost_amt'],
                      rate,            
                      g['award_amount'])
            total_awards+=g['award_amount']
            if g['indirect_cost_amt']:
                total_indirects+=g['indirect_cost_amt']
            print(line)
        print("{0} total # of grants...".format(len(self.grants)),file=sys.stderr)
        print("{0} total contact PI ...".format(len(PIs)),file=sys.stderr)
        print("$", "{:,} total awards.".format(total_awards),file=sys.stderr)
        print("$", "{:,} total indirects.".format(total_indirects),file=sys.stderr)
 
if __name__ == "__main__":
    main()

