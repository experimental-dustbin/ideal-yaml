#!/usr/bin/env ruby
require 'yaml'
require_relative './helpers'

persistence = Values[:artifactory][:persistence]
artifactory = Template[:artifactory]
pvc = {
  kind: "PersistentVolumeClaim",
  apiVersion: "v1",
  metadata: {
    name: artifactory[:fullname],
    labels: {
      app: artifactory[:name],
      chart: artifactory[:chart],
      release: Release[:Name],
      heritage: Release[:Service]
    },
    annotations: persistence[:annotations]
  },
  spec: {
    accessModes: persistence[:accessModes],
    resources: {
      requests: {
        storage: persistence[:size],
      }
    },
    storageClassName: persistence[:storageClass]
  }
}

STDOUT.puts pvc.to_yaml