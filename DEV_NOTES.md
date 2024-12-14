Development Notes:

- Added pod spec overrides to Argo Workflows to include affinities
    - TODO: make allowed instances environemnt variables

- TODO: make code from other Keda/Karpenter repo and check with official docs... from that repo below (existing notes)

- Karpenter folder
	- `createkarpenter.sh`
		- Install/Upgrade - Not right now: done in metaflow repo
			- But seems that's basically it.
			- COULD do an upgrade if karpenter config doesn't line up with extra opts set here
				- CHECK!
        - Need add scaled object
		- CFN: yes, mostly disruption QUEUE ... can target argo-ish
			- And add affinities in that podspec
		- Associate identities and the like to NodePool/NodeClass roles 
		- NodePool and NodeClass
			- Attach identities as in shell script
			"""
			- In Karpenter, NodePool and NodeClass are used to define and manage the characteristics and provisioning of nodes in a Kubernetes cluster. 
			- They do not apply to any specific deployment directly but rather to the nodes that can host any pods scheduled by the Kubernetes scheduler.
			"""
			- But I guess affinities or node targets go on the pod specs of certain deployments?
