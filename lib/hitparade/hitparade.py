#! /usr/bin/env python3

# Show used and available public cores. Break down used cores by user 
# and account
# hitparade refactor dirkpetersen / Oct 2017
#

import sys, os, argparse, subprocess, pandas, numpy 
import tempfile, datetime, re, glob, time, socket
import logging, csv, cmath, pwd, json, operator

class KeyboardInterruptError(Exception): pass

ignorenodetypes = ['gizmoc', 'gizmod', 'gizmoe']
privatetags = ['huang_y', 'bradley_p', 'halloran_b', 'peters_u', 'matsen_e']
maxpendingcores = 4999

def main():
    """
    Do some stuff, eventually printing output to stdout...
    """
    # Parse command-line arguments
    args = parse_arguments()

    # Logging setup
    if args.debug:
        logging.basicConfig(level=logging.DEBUG)
    else:
        logging.basicConfig(level=logging.WARNING)

    # replacing pyslurm with functions calling squeue and sinfo
    nodes = slurm_nodes(args)
    node_dict = nodes.to_dict(orient='index')
    
    jobs = slurm_jobs(args)
    job_dict = jobs.to_dict(orient='index')
    
    if len(node_dict) > 0 and len(job_dict) > 0:

        nt = get_nodetag(node_dict, job_dict, args)
        if args.debug:
            print('notetag',nt)
        #body = json.dumps(nt, sort_keys=True, indent=4)
        #print(body)
        pc = get_pending(job_dict)
        if args.debug:
            print('pending',pc)

        if args.csv:
            print_csv(args.csv_header_suppress, nt, pc)
        else:
            js=get_aggregated_jobs(job_dict, args)
            print_usage(js)
            get_max_idle_cores(node_dict,job_dict,args)
    else:

        print("No Nodes and/or no Jobs found !")


def get_max_idle_cores(node_dict,job_dict,args):

    idlecores={}

    for k, v in node_dict.items():
        idles = v['CPUS(A/I/O/T)'].split("/")
        if not v['STATE'].startswith('maint') and \
           not v['STATE'].startswith('resv') and \
           not v['STATE'].startswith('drng') and \
           not v['STATE'].startswith('drain'):
            idlecores[k] = int(idles[1])

    for k, v in job_dict.items():
        if v['PARTITION'].startswith('restart') and v['ST'] == 'R':
            if v['NODELIST'] in idlecores.keys():
                #print(v['NODELIST'],'adding',int(v['CPUS']),'cores')
                idlecores[v['NODELIST']]+=int(v['CPUS'])

    sidlecores = reversed(sorted(idlecores.items()))
    mostidle = max(sidlecores, key=operator.itemgetter(1))[0]

    totid = 0
    for k, v in idlecores.items():
        totid += v

    print ('\n   *** Currently max', idlecores[mostidle]-1, 'cores available on single node:', mostidle) 
    print ('   *** Total available:', totid,'cores (idle+restart) ***\n')

def slurm_jobs(args):
    
    squeuecmd = ['squeue', '--format=%i;%j;%P;%t;%D;%C;%a;%u;%N']

    headeroffset = 0
    if args.cluster != '':
        headeroffset = 1
        squeuecmd.append('--cluster=%s' % args.cluster)

    if args.partition != '':
        squeuecmd.append('--partition=%s' % args.partition)
                
    squeue = subprocess.Popen(squeuecmd, stdout=subprocess.PIPE)
    
    jobs=pandas.read_csv(squeue.stdout, sep=';', header=headeroffset)
    if args.partition != '':
        jobs = jobs[(jobs['PARTITION']==args.partition)] 

    # are there any jobs running
    if len(jobs.index) == 0:
        return {}
        
    jobs.set_index(['JOBID',], inplace=True)
   
    #print(jobs)
    return jobs
    
def slurm_nodes(args):
    
    sinfocmd = ['sinfo', '--format=%n;%c;%C;%m;%f;%O;%e;%t', '--responding']

    headeroffset = 0
    if args.cluster != '':
        headeroffset = 1
        sinfocmd.append('--cluster=%s' % args.cluster)
    
    if args.partition != '':
        sinfocmd.append('--partition=%s' % args.partition)        
        
    sinfo = subprocess.Popen(sinfocmd, stdout=subprocess.PIPE)
            
    nodes=pandas.read_csv(sinfo.stdout, sep=';', header=headeroffset)
    nodes.set_index(['HOSTNAMES',], inplace=True)
                
    return nodes

def print_usage(ajobs):
    for k,v in ajobs.items():
        print(("\n === Queue: %s ======= (R / PD) %s" % (k, "="*(12-len(k)))))
        tr=0
        tp=0
        #print('v:', v)
        for kk,vv in sorted( list(v.items()), key=lambda x: x[1], reverse=True):
            #print('vv:', vv)
            tr+=vv[0]
            tp+=vv[1]
            print(("{:>25} {:<5}".format( kk, "%s / %s" % (vv[0], vv[1]))))
        if len(v)>1:
            print(("{:>25} {:<5}".format( "TOTAL:", "%s / %s" % (tr, tp))))
        

def get_aggregated_jobs(job_dict, args):
    # account, user_id, job_state, partition, num_cpus, num_nodes

    ajobs={}

    for key, value in list(job_dict.items()):
        #luser=pwd.getpwuid(value['USER'])

        if args.pi:
            mykey = "%s" % value['ACCOUNT']
        else:
            mykey = "%s (%s)" % (value['ACCOUNT'], value['USER'])
        if value['PARTITION'] in ajobs:
            udict = ajobs[value['PARTITION']]
            if mykey in udict:
                ulist = udict[mykey]
            else:
                ulist = [0, 0]
        else:
            udict={}
            ulist = [0, 0]
            udict[mykey] = ulist             
        r=0
        p=0
        if value['ST'] == 'R':
            r = value['CPUS']
        elif value['ST'] == 'PD':
            p = value['CPUS']
        ulist[0]+=r
        ulist[1]+=p
        udict[mykey]=ulist
        ajobs[value['PARTITION']]=udict

##        if value['job_state'] != 'RUNNING':                     
##            print('account: %s' % value['account'])
##            print('user_id: %s' % luser[0])
##            #print('job_state: %s' % (value['job_state'][0]))
##            print('job_state: %s' % value['job_state'])
##            print(value['job_state'])
##            if value['job_state'][0] == 2:
##                print('*') * 60
##            print('partition: %s' % value['partition'])
##            print('num_cpus: %s' % value['num_cpus'])
##            print('-') * 40
        
    #body = json.dumps(ajobs, sort_keys=True, indent=4)
    #print(body)
            
    return ajobs

def print_csv(csv_header_suppress, nodetags, pendingcores):
    """
    Display totals to stdout in csv format. Unless --all is used,
    preemptees are not included.
    """

##--------------------------------------------------------------------------------
##Feature: [Installed, Allocated, Offline, Idle, LOAD, Restart(of allocated)]
##--------------------------------------------------------------------------------
##Total: [2952, 2759, 96, 97, 'Load:2361', 1187]
##campus,restart,rx200: [108, 105, 0, 3, 'Load:106', 0]
##campus,restart,x10sle: [720, 638, 0, 82, 'Load:491', 0]
##--------------------------------------------------------------------------------

    # Header
    if not csv_header_suppress:
        csv.writer(sys.stdout).writerow(['label', 'cores_total', 'cores_pending', 
            'cores_idle', 'cores_used_restart', 'cores_used_priority', 'unix_load'])

    # 'campus - public cores'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    label = 'campus - public cores'
    for key, value in sorted(nodetags.items()):        
        if key == 'Total':
            continue
        ntags = key.split(',')
        res = [value for value in privatetags if value in ntags] # get intersection of 2 lists 
        if not res:
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

        if 'campus' in pendingcores:
            cores_pending = pendingcores['campus']
        if 'campus-new' in pendingcores:
            cores_pending += pendingcores['campus-new']
        if 'largenode' in pendingcores:
            cores_pending += pendingcores['largenode']

        if cores_pending > maxpendingcores:
            cores_pending = maxpendingcores
            
    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])

    # 'all - entire cluster'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    for k, v in pendingcores.items():
        cores_pending+=v
    if cores_pending > maxpendingcores:
        cores_pending = maxpendingcores


    label = 'all - entire cluster'
    for key, value in sorted(nodetags.items()):
        if key.startswith('Total'):
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])


    # 'grabnode - public nodes'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    label = 'grabnode - public nodes'
    for key, value in sorted(nodetags.items()):
        if key.startswith('grab,'):         
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

   # csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
   #             cores_used_restart, cores_used_priority, unix_load])


    # 'largenode - public cores'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    
    for key, value in sorted(nodetags.items()):
        if key.endswith(',gizmoh'):
            #label = 'largenode - GizmoH'
            label = 'largenode - public cores'
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    #csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
    #            cores_used_restart, cores_used_priority, unix_load])


    # 'private nodes'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]

    label = 'private nodes'
    for key, value in sorted(nodetags.items()):

        if key == 'Total':
            continue
        ntags = key.split(',')
        res = [value for value in privatetags if value in ntags] # get intersection of 2 lists 
        if res:
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])


    # 'Gizmo F nodes'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    label = 'Gizmo F nodes'

    for key, value in sorted(nodetags.items()):
        if 'gizmof' in key:
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])


    # 'Gizmo G nodes'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    label = 'Gizmo G nodes'

    for key, value in sorted(nodetags.items()):
        if 'gizmog' in key:
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])


    # 'Gizmo H nodes'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    label = 'Gizmo H nodes'

    for key, value in sorted(nodetags.items()):
        if 'gizmoh' in key:
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])


    # 'Gizmo J nodes'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    label = 'Gizmo J nodes'

    for key, value in sorted(nodetags.items()):
        if 'gizmoj' in key:
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])


    # 'Gizmo K nodes'
    cores_total, cores_pending, cores_idle, cores_used_restart, cores_used_priority, unix_load = [0, 0, 0, 0, 0, 0]
    label = 'Gizmo K nodes'

    for key, value in sorted(nodetags.items()):
        if 'gizmok' in key:
            cores_total+=value[0]-value[2]
            cores_idle+=value[3]
            cores_used_restart+=value[5]
            cores_used_priority+=value[1]-value[5]
            unix_load+=int(value[4])

    csv.writer(sys.stdout).writerow([label, cores_total, cores_pending, cores_idle,
                cores_used_restart, cores_used_priority, unix_load])

    
def get_pending(job_dict):
    """ 
    get dictionary of pending jobs by partition 
    """

    pendingcores={}

    for key1, value1 in job_dict.items():
        if value1['ST'] == 'PD':  # is the job pending
            pcores = int(value1['CPUS'])
            if value1['PARTITION'] in pendingcores:
                pcores += pendingcores[value1['PARTITION']]
            pendingcores[value1['PARTITION']] = pcores

    #print(pendingcores)
    return pendingcores


def get_nodetag(node_dict, job_dict, args):

    if node_dict and job_dict:

#       print "-" * 80

        nodetag={}
        nodetag["Total"] = [0,0,0,0,0,0]

        restartcores={}
        extrarestartcores=0 # multi node restart jobs cannot be easily assigned to a tag 

        for key1, value1 in job_dict.items():

            if value1['ST'] == 'R':  # is the job running
                if value1['PARTITION'].startswith('restart'):
                    if int(value1['NODES']) > 1:
                        print("more than 1 node in restart job: adding restart cores only to Total!!!")
                        extrarestartcores += int(value1['CPUS'])

                    else:
                        node = value1['NODELIST']
                        rcores=0
                        if node in restartcores:
                            rcores=restartcores[node]
                        restartcores[node]=rcores+int(value1['CPUS'])

        for key, value in node_dict.items():

            cont=0
            for typ in ignorenodetypes:
                if key.startswith(typ):
                    cont=1
            if cont==1:
                continue

            cpuinst = value['CPUS']
            #cpualloc = int(abs(cmath.sqrt(value['alloc_cpus'])))
            cpualloc = int(value['CPUS(A/I/O/T)'].split('/')[0])
            cpuoffline = int(value['CPUS(A/I/O/T)'].split('/')[2])
            cpuinst = cpuinst-cpuoffline
            #cpuidle = cpuinst-cpualloc
            cpuidle = int(value['CPUS(A/I/O/T)'].split('/')[1])
            if value['STATE'].startswith('maint') or \
               value['STATE'].startswith('drng') or \
               value['STATE'].startswith('drain'):
                cpuidle = 0
            cpuload = value['CPU_LOAD']
            cpurestart = 0
            if key in restartcores:
                cpurestart = restartcores[key]
            features = value['AVAIL_FEATURES']+','+key[:6]
            #print('feaures:', features, value['FEATURES'])
            
            ##print('state',value['state'][0])

            if cpuload > 1000:   # down or drained node
                cpuoffline = value['CPUS']
                cpualloc = 0
                cpuidle = 0
                cpuload = 0
                cpurestart = 0


            if args.debug:
                print((key,features,cpuinst,cpualloc,cpuidle,cpuload,cpurestart,value['STATE']))
                
            #print (nodetag)
            
            

            if features in nodetag:
                nclass = nodetag[features]
                #print('features' ,'nodetag')
                #print(features, nodetag)
                #print('end features' ,'end nodetag')
                
                
                nodetag[features]=[nclass[0]+cpuinst,nclass[1]+cpualloc,nclass[2]+cpuoffline,
                    nclass[3]+cpuidle,nclass[4]+cpuload,nclass[5]+cpurestart]
            else:
                nodetag[features]=[cpuinst,cpualloc,cpuoffline,cpuidle,cpuload,cpurestart]

            total = nodetag["Total"]
            
            nodetag["Total"]=[total[0]+cpuinst,total[1]+cpualloc,
                total[2]+cpuoffline,total[3]+cpuidle,total[4]+cpuload,total[5]+cpurestart]


        total = nodetag["Total"]
        total[5]+=extrarestartcores   # adding cores from multi-node restart jobs
        nodetag["Total"]=total  #
        #print(nodetag)
        #body = json.dumps(nodetag, sort_keys=True, indent=4)
        #print(body)
        return nodetag

def parse_arguments():
    """
    Gather command-line arguments.
    """

    parser = argparse.ArgumentParser(prog='hitparade.py',
        description='Show cluster users and basic usage stats for public ' + \
        'nodes and cores.')
    parser.add_argument( '--debug', '-d', action='store_true', default=False,
        help='Turn on debugging output.')
    parser.add_argument( '--all', '-a', dest='all_jobs', action='store_true', 
        help='Show all core usage.  If set, results will include preemptees',
        default=False )
    parser.add_argument( '--cluster', '-M', dest='cluster',
        action='store',
        help='name of the slurm cluster, (default: current cluster)',
        default='' )              
    parser.add_argument( '--partition', '-p', dest='partition',
        action='store',
        help='partition of the slurm cluster (default: entire cluster)',
        default='' )
    parser.add_argument( '--csv', '-c', dest='csv', action='store_true', 
        help='Output core and node totals to csv.',
        default=False )
    parser.add_argument( '--csv-header-suppress', '-s', dest='csv_header_suppress', 
        action='store_true', 
        help='Used with --csv, suppresses header. Default is False, show header.',
        default=False )
    parser.add_argument( '--pi', '-P', dest='pi', action='store_true', 
        help='Aggregate data by PI only.',
        default=False )
    parser.add_argument( '--free-cores', '-f', dest='free_cores', 
        action='store_true', 
        help='Print free cores and exit.',
        default=False )

    return parser.parse_args()


if __name__ == '__main__':
    sys.exit(main())
