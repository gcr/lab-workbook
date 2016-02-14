from sys import exit
try:
    import setuptools
except:
    from sys import stdout
    stdout.write('''
setuptools not found. Please install it.

On linux, the package is often called python-setuptools\n''')
    exit(1)

long_description = open('README.md').read()

classifiers = [
    'Development Status :: 1 - Pre-Alpha',
    'Environment :: Console',
    'License :: OSI Approved :: zlib/libpng License',
    'Operating System :: POSIX',
    'Programming Language :: Python',
    'Programming Language :: Lua',
    'Topic :: Scientific/Engineering',
    'Topic :: Software Development',
    'Topic :: System :: Distributed Computing',
    'Intended Audience :: Science/Research',
]

setuptools.setup(name = 'lab_workbook',
      version = '0.0.1',
      description = 'An organized workflow for your machine learning experiments.',
      long_description = open('README.md').read(),
      author = 'Michael Wilber',
      author_email = 'mjw285@cornell.edu',
      license = 'zlib',
      platforms = ['Any'],
      classifiers = classifiers,
      url = 'https://github.com/gcr/lab-workbook',
      packages = setuptools.find_packages(),
      install_requires=['boto', 'pandas'],
)
