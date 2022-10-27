#! /usr/bin/python3

import os, sys, time
import json, subprocess, shlex
from rich.console import Console
from rich.columns import Columns
from rich.panel import Panel
from rich.prompt import Prompt

def main():
    console = Console()
    mystyle = "green on black"
    myroot = os.getenv('HPCTOYS_ROOT')
    if not myroot:
        msg = "environment var HPCTOYS_ROOT not set, exiting.."
        console.print(msg, style=mystyle)
        return False
    f = open(os.path.join(myroot,'etc','hpctoys-menu.json'))
    myjson = json.load(f)
    keys = get_values(myjson,"key",lower=True)
    entries_renderable = [Panel(get_entry(record), 
                           expand=True) for record in myjson]
    while True:
        console.clear()
        console.print(Columns(entries_renderable))
        try:
            msg = "Enter lowercase key for  menu choice:"
            sel = Prompt.ask(msg, choices=keys, show_choices=True)
        except KeyboardInterrupt as e:
            return True
        cmd = query_value(myjson, "key", sel, "cmd", icase=True)
        if cmd == 'exit':
          console.print("restart menu with command 'hpctoys' !", style=mystyle)
          return True

        console.print("executing '%s' ..." % cmd, style=mystyle)

        try:
            subprocess.run(cmd,shell=True, check=True)
        except subprocess.CalledProcessError as e:
            print("CalledProcessError:", str(e) )
            #return False
        except Exception as e:
            print("Other Error:", str(e))
            #return False
        #return True  # for debugging 

def get_entry(item):
    """Extract text from menu dict."""
    title = item["title"]
    key = item["key"]
    lines = item["text"]
    text = "\n".join(lines)
    return f"[b]{title}[/b] [red]({key})[/red]\n[yellow]{text}"

def query_value(entries, key, val, returnkey, icase=False):
    for entry in entries:
        if key in entry:
            if icase:
                if entry[key].lower() == val.lower():
                    return entry[returnkey]                
            else:
                if entry[key] == val:
                    return entry[returnkey]

def get_values(entries,key, lower=False):
    values=[]
    for entry in entries:
        if key in entry:
            if lower:
               values.append(entry[key].lower())
            else:
               values.append(entry[key])
    return values

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print ('Exit !')
