from setuptools import setup, find_packages

setup(
    name='jira-event-handler',
    version='1.0.0',
    description='Lambda function for processing Jira events and sending Teams notifications',
    author='DevOps Team',
    packages=find_packages(where='src'),
    package_dir={'': 'src'},
    python_requires='>=3.9',
    install_requires=[
        'requests>=2.31.0',
        'urllib3>=2.1.0',
        'boto3>=1.29.7',
    ],
    extras_require={
        'dev': [
            'pytest>=7.4.3',
            'pytest-cov>=4.1.0',
        ],
    },
)
