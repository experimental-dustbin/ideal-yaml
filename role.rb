require 'yaml'
require_relative './helpers'

artifactory = Template[:artifactory]
role = {
  apiVersion: "rbac.authorization.k8s.io/v1",
  kind: "Role",
  metadata: {
    labels: {
      app: artifactory[:name],
      chart: artifactory[:chart],
      component: Values[:artifactory][:name],
      heritage: Release[:Service],
      release: Release[:Name]
    },
    name: artifactory[:fullname]
  },
  rules: Values[:rbac][:role][:rules]
}

STDOUT.puts role.to_yaml