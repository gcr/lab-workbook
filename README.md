Lab Workbook
============

An organized workflow for your Torch machine learning experiments.

![workflow example](lab-workbook.jpeg)

If you have many experiments to run, it can be hard to keep track of
them. This library solves three problems:

- **Capturing experimental artifacts** like loss functions, Torch
  models, time series, etc. from your Torch experiments to a permanent
  location (Amazon S3);
- **Helping you analyze results** by making each artifact readily
  available inside an IPython Notebook for easy plotting;
- **Helping you plan which experiments to run** by keeping each
  experiment separate, immutable, and easily referable.

How to set up
=============
**On your experiment sserver:**

- **Install Torch.**
- **Set up and configure the AWS Command Line tools**, which is the
  `awscli` PyPI Python package. The `aws` command should be in your
  `$PATH`. You can use `aws configure` to enter your IAM credentials.
  At this point, running `aws list` in the shell should show you a
  list of your S3 buckets. (This library will call the `aws` binary)
- **Install the workbook** using Luarocks. At the time of writing,
  this package is not available on the Rocks server, so you must
  install it from github manually.

    git clone https://github.com/gcr/lab-workbook lab-workbook
    cd lab-workbook
    luarocks make

- **Configure the workbook** by creating `~/.lab-workbook-config` with
  the following contents:

    bucketPrefix = s3://your-bucket/experiments/

  where `your-bucket` is the name of your S3 bucket and `experiments/`
  is the S3 prefix to save all experiments to. Be sure this path ends
  with `/` if you want to save experiments within this folder!
