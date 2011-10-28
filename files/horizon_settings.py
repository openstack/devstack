import os

DEBUG = True
TEMPLATE_DEBUG = DEBUG
PROD = False
USE_SSL = False

LOCAL_PATH = os.path.dirname(os.path.abspath(__file__))

# FIXME: We need to change this to mysql, instead of sqlite.
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': os.path.join(LOCAL_PATH, 'dashboard_openstack.sqlite3'),
    },
}

CACHE_BACKEND = 'dummy://'

# Add apps to horizon installation.
INSTALLED_APPS = (
    'dashboard',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_openstack',
    'django_openstack.templatetags',
    'mailer',
)


# Send email to the console by default
EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
# Or send them to /dev/null
#EMAIL_BACKEND = 'django.core.mail.backends.dummy.EmailBackend'

# django-mailer uses a different settings attribute
MAILER_EMAIL_BACKEND = EMAIL_BACKEND

# Configure these for your outgoing email host
# EMAIL_HOST = 'smtp.my-company.com'
# EMAIL_PORT = 25
# EMAIL_HOST_USER = 'djangomail'
# EMAIL_HOST_PASSWORD = 'top-secret!'

# FIXME: This needs to be changed to allow for multi-node setup.
OPENSTACK_KEYSTONE_URL = "http://localhost:5000/v2.0/"
OPENSTACK_KEYSTONE_ADMIN_URL = "http://localhost:35357/v2.0"
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "Member"

# NOTE(tres): Available services should come from the service
#             catalog in Keystone.
SWIFT_ENABLED = False

# Configure quantum connection details for networking
QUANTUM_ENABLED = False
QUANTUM_URL = '127.0.0.1'
QUANTUM_PORT = '9696'
QUANTUM_TENANT = '1234'
QUANTUM_CLIENT_VERSION='0.1'

# No monitoring links currently
EXTERNAL_MONITORING = []

# Uncomment the following segment to silence most logging
# django.db and boto DEBUG logging is extremely verbose.
#LOGGING = {
#        'version': 1,
#        # set to True will disable all logging except that specified, unless
#        # nothing is specified except that django.db.backends will still log,
#        # even when set to True, so disable explicitly
#        'disable_existing_loggers': False,
#        'handlers': {
#            'null': {
#                'level': 'DEBUG',
#                'class': 'django.utils.log.NullHandler',
#                },
#            'console': {
#                'level': 'DEBUG',
#                'class': 'logging.StreamHandler',
#                },
#            },
#        'loggers': {
#            # Comment or Uncomment these to turn on/off logging output
#            'django.db.backends': {
#                'handlers': ['null'],
#                'propagate': False,
#                },
#            'django_openstack': {
#                'handlers': ['null'],
#                'propagate': False,
#            },
#        }
#}

# How much ram on each compute host?
COMPUTE_HOST_RAM_GB = 16
