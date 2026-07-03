#!/usr/bin/env python3
"""Approve all open pull requests in the repo using a provided GitHub token.

Usage:
  GITHUB_TOKEN=ghp_xxx python scripts/approve_prs.py
"""
import os
import sys
import requests

TOKEN = os.environ.get('GITHUB_TOKEN')
REPO = os.environ.get('GITHUB_REPOSITORY', 'shaikchandol/VSCode')

if not TOKEN:
    print('Missing GITHUB_TOKEN environment variable', file=sys.stderr)
    sys.exit(1)

API = 'https://api.github.com'
headers = {'Authorization': f'token {TOKEN}', 'Accept': 'application/vnd.github+json'}

def list_prs():
    url = f'{API}/repos/{REPO}/pulls?state=open&per_page=100'
    r = requests.get(url, headers=headers)
    r.raise_for_status()
    return r.json()

def approve(pr_number):
    url = f'{API}/repos/{REPO}/pulls/{pr_number}/reviews'
    data = {'body': 'Auto-approved by script', 'event': 'APPROVE'}
    r = requests.post(url, headers=headers, json=data)
    r.raise_for_status()
    return r.json()

def main():
    prs = list_prs()
    if not prs:
        print('No open PRs')
        return
    for pr in prs:
        num = pr['number']
        print(f'Approving PR #{num} - {pr["title"]}')
        approve(num)
    print('Done')

if __name__ == '__main__':
    main()
