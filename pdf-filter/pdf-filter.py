#!/usr/bin/env python

from PyPDF2 import PdfFileReader, PdfFileWriter
from sys import argv
import subprocess
import re

def filter_pdf(path : str, pat = "Definition:|Theorem:|Remark:"):
    '''Write a new PDF file from a PDF file with pages filtered according to pattern'''
    wpath = path.replace('.pdf', f'-only-{sanitize(pat)}.pdf');

    reader = PdfFileReader(path)
    writer = PdfFileWriter()

    page_idxs = filter(lambda idx: filt_cond(extract(path, idx+1), pat), range(len(reader.pages)))
    pages = map(lambda idx: reader.getPage(idx), page_idxs)

    for page in pages:
        writer.addPage(page)
    with open(wpath, 'wb') as f:
        writer.write(f)

def sanitize(text : str) -> str:
    '''Return a string to represent a regex pattern in a filename'''
    return '-'.join(re.findall("[A-Za-z]+", text))

def extract(path : str, num : int) -> str:
    '''Extract text from the n-th page of a PDF (one-based)'''
    proc = subprocess.Popen(['pdftotext', '-f', str(num), '-l', str(num), path, '-'],
                            stdout=subprocess.PIPE)
    return str(proc.stdout.read())

def filt_cond(text : str, pat : str) -> bool:
    return bool(re.search(pat, text))

if __name__ == '__main__':
    assert(argv[1].endswith('.pdf'))
    filter_pdf(argv[1], argv[2])
