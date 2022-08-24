# ECS Compatibility Support in logstash-output-opensearch
Compatibility for ECS v8 was added in release 1.3.0 of the plugin. This would enable the plugin to work with Logstash 8.x without the need to disable ecs_compatibility.  
The output plugin doesn't create any events itself, but merely forwards events to OpenSearch that were shaped by plugins preceding it in the pipeline. So, it doesn't play a direct role in making the events ECS compatible.  
However, the default index templates that the plugin installs into OpenSearch in the ecs_compatibility modes (v1 & v8) ensures that the document fields stored in the indices are ECS compatible. OpenSearch would throw errors for documents that have fields which are ECS incompatible and can't be coerced. 

## ECS index templates used by logstash-output-opensearch 1.3.0
* v8 [ECS 8.0.0](https://github.com/elastic/ecs/releases/tag/v8.0.0) [ecs-8.0.0/generated/elasticsearch/legacy/template.json](https://raw.githubusercontent.com/elastic/ecs/v8.0.0/generated/elasticsearch/legacy/template.json)
* v1 [ECS 1.9.0](https://github.com/elastic/ecs/releases/tag/v1.9.0) [ecs-1.9.0/generated/elasticsearch/7/template.json](https://raw.githubusercontent.com/elastic/ecs/v1.9.0/generated/elasticsearch/7/template.json)
  
## ECS incompatibility
Incompatibility can arise for an event when it has fields with the same name as an ECS defined field but a type which can't be coerced into the ECS field.  
It is Ok to have fields that are not defined in ECS [ref](https://www.elastic.co/guide/en/ecs/current/ecs-faq.html#addl-fields).
The dynamic template included in the ECS templates would dynamically map any non-ECS fields. 

### Example 
[ECS defines the "server"](https://www.elastic.co/guide/en/ecs/current/ecs-server.html) field as an object. But let's say the plugin gets the event below, with a string in the `server` field. It will receive an error from OpenSearch as strings can't be coerced into an object and the ECS incompatible event won't be indexed.
```
{
	"@timestamp": "2022-08-22T15:39:18.142175244Z",
	"@version": "1",
	"message": "Doc1",
	"server": "remoteserver.com"
}
```

Error received from OpenSearch in the Logstash logs
```
[2022-08-23T00:01:53,366][WARN ][logstash.outputs.opensearch][main][a36555c6fad3f301db8efff2dfbed768fd85e0b6f4ee35626abe62432f83b95d] Could not index event to OpenSearch. {:status=>400, :action=>["index", {:_id=>nil, :_index=>"ecs-logstash-2022.08.23", :routing=>nil}, {"@timestamp"=>2022-08-22T15:39:18.142175244Z, "@version"=>"1", "server"=>"remoteserver.com", "message"=>"Doc1"}], :response=>{"index"=>{"_index"=>"ecs-logstash-2022.08.23", "_id"=>"CAEUyYIBQM7JQrwxF5NR", "status"=>400, "error"=>{"type"=>"mapper_parsing_exception", "reason"=>"object mapping for [server] tried to parse field [server] as object, but found a concrete value"}}}}
```
## How to make things compatible
* As mentioned at the beginning, the plugins in the pipeline that create the events like the `input` and `codec` plugins should all use ECS defined fields. 
* Filter plugins like [mutate](https://github.com/logstash-plugins/logstash-filter-mutate/blob/main/docs/index.asciidoc) can be used to map incompatible fields into ECS compatible ones.  
In the above example the `server` field can be mapped to the `server.domain` field.  
* You can use your own custom template in the plugin using the `template` and `template_name` configs.  
 [According to this](https://www.elastic.co/guide/en/ecs/current/ecs-faq.html#type-interop) some field types can be changed while staying compatible.

As a last resort the `ecs_compatibility` of the logstash-output-opensearch can be set to `disabled`.
     

_______________
## References
* [Elastic Common Schema (ECS) Reference](https://www.elastic.co/guide/en/ecs/current/index.html)
