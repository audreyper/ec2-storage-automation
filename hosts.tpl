%{ for instance in instance_info }
${instance.public_ip}
%{ for block in instance.block_devices }
%{ for k,v in block }
${k}: ${v}
%{ endfor }
%{ endfor }
%{ endfor }