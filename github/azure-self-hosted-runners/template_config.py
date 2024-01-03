import os, sys, json
from jinja2 import Environment, FileSystemLoader, StrictUndefined

template = sys.argv[1]
environment = Environment(loader=FileSystemLoader("templates/"), undefined=StrictUndefined)
template = environment.get_template(template)

github_config_json = os.environ['GITHUB_CONFIG']
github_config = json.loads(github_config_json)
rendered_config = template.render(env=os.environ, github_config=github_config)

print(rendered_config)
