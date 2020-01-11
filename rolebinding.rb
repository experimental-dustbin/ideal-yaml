require 'yaml'
require_relative './helpers'

artifactory = Template[:artifactory]
rolebinding = {
  apiVersion: "rbac.authorization.k8s.io/v1",
  kind: "RoleBinding",
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
  subjects: {
    kind: "ServiceAccount",
    name: artifactory[:serviceAccountName]
  },
  roleRef: {
    kind: "Role",
    apiGroup: "rbac.authorization.k8s.io",
    name: artifactory[:fullname]
  }
}

STDOUT.puts rolebinding.to_yaml