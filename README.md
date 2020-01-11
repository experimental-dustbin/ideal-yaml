# Code vs Templates

I consistently see people reaching for a templating system to parametrize various bits and
pieces that deal with cloud/infrastructure tooling. I personally think this is the wrong
way to go about making infrastructure more manageable because templates lack all the abstracting
facilities that can be found in real programming languages. But instead of making this another opinion
piece I'm going to take a helm chart and convert it to code so we can do a side by side comparison.

I'm going to use https://github.com/helm/charts/tree/master/stable/artifactory/templates. I'll start
at the top and go down. The initial conversion will be pretty simple and then we'll use Ruby's actual
abstraction capabilities and see how far we get.

# First Pass

Here's `artifactory-pvc.yaml`

```
{{- if and .Values.artifactory.persistence.enabled (not .Values.artifactory.persistence.existingClaim) -}}
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: {{ template "artifactory.fullname" . }}
  labels:
    app: {{ template "artifactory.name" . }}
    chart: {{ template "artifactory.chart" . }}
    release: {{ .Release.Name }}
    heritage: {{ .Release.Service }}
{{- if .Values.artifactory.persistence.annotations }}
  annotations:
{{ toYaml .Values.artifactory.persistence.annotations | indent 4 }}
{{- end }}
spec:
  accessModes:
    - {{ .Values.artifactory.persistence.accessMode | quote }}
  resources:
    requests:
      storage: {{ .Values.artifactory.persistence.size | quote }}
{{- if .Values.artifactory.persistence.storageClass }}
{{- if (eq "-" .Values.artifactory.persistence.storageClass) }}
  storageClassName: ""
{{- else }}
  storageClassName: "{{ .Values.artifactory.persistence.storageClass }}"
{{- end }}
{{- end }}
{{- end }}
```

Here's the naive translation

```Ruby
#!/usr/bin/env ruby
require 'yaml'

Values = ->(sym) {
  # ...
}

Release = ->(sym) {
  # ...
}

Template = ->(sym) {
  # ...
}

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
```

The translation logic is pretty simple. All top level elements become callable objects. In Ruby lambdas can be called
using the same syntax as accessing entries in a hash map so this gives us syntactic flexibility and simplifies the API because
fundamentally we don't care if we're accessing keys in a hash map or calling a lambda that goes through some complicated
logic to give us the value associated with the key. I redacted the lambdas but they're pretty simple. Here's what the `Release`
one looks like

```ruby
Release = ->(sym) {
  case sym
  when :Name
    ""
  when :Service
    ""
  else
    raise StandardError, "Unknown key: #{sym}."
  end
}
```

Since we are working in a real programming language we can factor out these pieces into their own files. I'm going
to move all the top level lambdas to `helpers.rb`. So what we are left with at the end of the day is just the logic
relevant for the "persistent volume claim"

```ruby
#/usr/bin/env ruby
require 'yaml'
require_relative './helpers'

# ...
```

Let's do the same for a few more yaml files to get a feel for it. Here's `artifactory-role.yaml`

```ruby
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
```

Already there is a nice benefit, when you try to run this you will get an error message

```
$ ruby role.rb
Traceback (most recent call last):
        1: from role.rb:18:in `<main>'
/mnt/c/code/helpers.rb:17:in `block in <top (required)>': Unknown key: rbac. (StandardError)
```

That's pretty nice if you ask me. The key doesn't exist so we get a legitimate error message telling
us exactly what is going on. To fix the problem we can extend `Values` with the required logic to give
us what we need. I'm just going to make it another empty hash map to proceed but the logic can be as
simple or as complicated as you want it to be.

```
$ ruby role.rb
---
:apiVersion: rbac.authorization.k8s.io/v1
:kind: Role
:metadata:
  :labels:
    :app: ''
    :chart: ''
    :component:
    :heritage: ''
    :release: ''
  :name: ''
:rules: ''
```

Ok, one more to drive the point home. Here's `artifactory-rolebinding.yaml`

```ruby
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
```

When we run it we get the following output

```
$ ruby rolebinding.rb
---
:apiVersion: rbac.authorization.k8s.io/v1
:kind: RoleBinding
:metadata:
  :labels:
    :app: ''
    :chart: ''
    :component: ''
    :heritage: ''
    :release: ''
  :name: ''
:subjects:
  :kind: ServiceAccount
  :name: ''
:roleRef:
  :kind: Role
  :apiGroup: rbac.authorization.k8s.io
  :name: ''
```

Hopefully you're getting the idea. Using code gives us much more flexibility than using a simple
templating language and allows us to abstract repetitive work through whatever language facilities
we have at our disposal. We can perform whatever transformations are necessary using code and then
at the end output whatever YAML files are expected by K8s. Presumably Helm handles some of this
logic as well but I suspect writing a driver to push YAML files to K8s is pretty simple and
does not require buying into a templating system to go along with it.