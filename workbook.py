#!/usr/bin/env python

import ConfigParser
import os
import boto
import urllib2
import pandas
import json

from StringIO import StringIO
from boto.s3.connection import S3Connection

def guess_bucket_and_prefix():
    """Read the S3 bucket and prefix from the user's config file, located
    at ~/.lab-workbook-config. The file should have the following
    contents:

        bucketPrefix = s3://my-bucket-name/experiments/

    This function will then return ("my-bucket-name", "experiments")

    """
    config = ConfigParser.ConfigParser()
    with open(os.path.expanduser("~/.lab-workbook-config")) as f:
        buffer = "[general]\n"+f.read()
    config.readfp(StringIO(buffer))
    s3url = config.get("general", "bucketPrefix")
    url = urllib2.urlparse.urlparse(s3url)
    return url.netloc, url.path

ARTIFACT_PROCESSORS = []
def artifact_processor(f):
    """Registers `f` as an artifact processor, which will be called with
    (name, contents) and should return either an updated version of
    `contents` or None.
    """
    ARTIFACT_PROCESSORS.append(f)
    return f


class ExperimentRepository(object):
    """
    A collection of experiments.
    """
    def __init__(self, bucket=None, s3prefix=None):
        self.con = S3Connection()
        if not (bucket and prefix):
            bucket, prefix = guess_bucket_and_prefix()
        self.bucket = self.con.get_bucket(bucket)
        self.prefix = prefix
        if self.prefix.startswith("/"):
            self.prefix = self.prefix[1:]

    def list_experiments(self):
        results = []
        for key in self.bucket.list(self.prefix, delimiter="/"):
            results.append(Experiment(key.name, self.bucket))
        return results

    def get(self, experiment_name):
        return Experiment(self.prefix+experiment_name, self.bucket)

    def __getitem__(self, key):
        if isinstance(key, str):
            return self.get(key)
        elif isinstance(key, tuple):
            return tuple([self.get(k) for k in key])
        else:
            return self.list_experiments()[key]

    def meld_csv(self, experiment_mapping, artifact, column):
        df = pandas.DataFrame()
        frames = []
        names = []
        for expname,label in experiment_mapping.items():
            frames.append(self[expname][artifact][column])
            names.append(label)
        return pandas.concat(frames, axis=1, keys=names)



class Experiment(object):
    def __init__(self, prefix, bucket):
        self.prefix = prefix
        if not self.prefix.endswith("/"):
            self.prefix += "/"
        self.bucket = bucket

    def __repr__(self):
        return "<Experiment: {}>".format(
            os.path.basename(os.path.dirname(self.prefix))
        )

    def list_artifacts(self):
        results = []
        for key in self.bucket.list(self.prefix, delimiter="/"):
            results.append(key.name.replace(self.prefix,""))
        return results

    def get(self, artifact_name):
        contents = self.bucket.get_key(self.prefix+artifact_name).get_contents_as_string()
        for processor in ARTIFACT_PROCESSORS:
            result = processor(artifact_name, contents)
            if result is not None:
                return result
        # No processor? Too bad... :-(
        return contents

    def __getitem__(self, key):
        if isinstance(key, str):
            return self.get(key)
        elif isinstance(key, tuple):
            return tuple([self.get(k) for k in key])
        else:
            return self.list_artifacts()[key]




@artifact_processor
def csv_artifact(name, contents):
    if name.endswith(".csv"):
        # Parse with Pandas!
        return pandas.read_csv(
            StringIO(contents),
            index_col=0,
            parse_dates=['Date'],
            na_values=["nil"],

        )

@artifact_processor
def json_artifact(name, contents):
    if name.endswith(".json"):
        # Load into JSON!
        return json.loads(contents)
