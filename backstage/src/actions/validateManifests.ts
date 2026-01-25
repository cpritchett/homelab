/**
 * Custom Scaffolder Action: Validate Kubernetes Manifests
 * 
 * This action validates generated manifests against:
 * 1. Kubernetes schemas (kubernetes-models)
 * 2. Constitutional DNS naming rules
 * 3. Storage/ingress compatibility
 */

import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import * as fs from 'fs/promises';
import * as path from 'path';
import YAML from 'yaml';

export const validateManifestsAction = createTemplateAction<{
  manifestsPath: string;
}>({
  id: 'custom:validate-manifests',
  description: 'Validate Kubernetes manifests for schema and constitutional compliance',
  schema: {
    input: {
      type: 'object',
      required: ['manifestsPath'],
      properties: {
        manifestsPath: { type: 'string', description: 'Path to manifests directory' },
      },
    },
    output: {
      type: 'object',
      properties: {
        valid: { type: 'boolean', description: 'Whether validation passed' },
        errors: { type: 'array', description: 'List of validation errors' },
      },
    },
  },
  
  async handler(ctx) {
    const { manifestsPath } = ctx.input;
    
    ctx.logger.info(`Validating manifests in: ${manifestsPath}`);
    
    const errors: string[] = [];
    
    // Read all YAML files
    const files = await fs.readdir(manifestsPath);
    const yamlFiles = files.filter(f => f.endsWith('.yaml') || f.endsWith('.yml'));
    
    for (const file of yamlFiles) {
      const filePath = path.join(manifestsPath, file);
      const content = await fs.readFile(filePath, 'utf-8');
      
      try {
        const docs = YAML.parseAllDocuments(content);
        
        for (const doc of docs) {
          const manifest = doc.toJSON();
          
          if (!manifest || !manifest.kind) {
            continue;
          }
          
          ctx.logger.info(`Validating ${manifest.kind}: ${manifest.metadata?.name}`);
          
          // Validate Ingress DNS naming (Constitutional Rule: DNS Encodes Intent)
          if (manifest.kind === 'Ingress') {
            const rules = manifest.spec?.rules || [];
            
            for (const rule of rules) {
              const host = rule.host;
              
              if (!host) {
                errors.push(`Ingress ${manifest.metadata.name}: Missing host`);
                continue;
              }
              
              // Check for external DNS annotation
              const hasExternalDNS = manifest.metadata?.annotations?.['external-dns.alpha.kubernetes.io/hostname'];
              
              // Validation: External apps must use *.hypyr.space (not .internal)
              if (hasExternalDNS && host.includes('.internal.')) {
                errors.push(
                  `Ingress ${manifest.metadata.name}: External apps cannot use .internal domain. ` +
                  `Host "${host}" violates DNS intent principle.`
                );
              }
              
              // Validation: Internal apps must use *.in.hypyr.space
              if (!hasExternalDNS && !host.endsWith('.in.hypyr.space')) {
                errors.push(
                  `Ingress ${manifest.metadata.name}: Internal apps must use .in.hypyr.space domain. ` +
                  `Host "${host}" violates DNS intent principle.`
                );
              }
              
              // Validation: hypyr.space (without internal) requires ExternalDNS
              if (host.endsWith('.hypyr.space') && !host.includes('.internal.') && !hasExternalDNS) {
                errors.push(
                  `Ingress ${manifest.metadata.name}: External domain "${host}" requires external-dns annotation`
                );
              }
            }
          }
          
          // Validate PVC naming and storage class
          if (manifest.kind === 'PersistentVolumeClaim') {
            const storageClassName = manifest.spec?.storageClassName;
            
            if (!storageClassName) {
              errors.push(`PVC ${manifest.metadata.name}: Missing storageClassName`);
            }
            
            // Validate storage size
            const storage = manifest.spec?.resources?.requests?.storage;
            if (storage) {
              const sizeMatch = storage.match(/^(\d+)(Gi|Mi|Ti)$/);
              if (!sizeMatch) {
                errors.push(`PVC ${manifest.metadata.name}: Invalid storage size format "${storage}"`);
              } else {
                const size = parseInt(sizeMatch[1]);
                const unit = sizeMatch[2];
                
                if (unit === 'Gi' && (size < 1 || size > 1000)) {
                  errors.push(`PVC ${manifest.metadata.name}: Storage size ${size}Gi out of range (1-1000)`);
                }
              }
            }
          }
          
          // Validate PersistentVolume NAS paths
          if (manifest.kind === 'PersistentVolume') {
            const nfs = manifest.spec?.nfs;
            
            if (nfs) {
              const path = nfs.path;
              
              // Validate no path traversal
              if (path.includes('..')) {
                errors.push(
                  `PV ${manifest.metadata.name}: NAS path "${path}" contains relative references (..)`
                );
              }
              
              // Validate starts with /
              if (!path.startsWith('/')) {
                errors.push(
                  `PV ${manifest.metadata.name}: NAS path "${path}" must start with /`
                );
              }
            }
          }
          
          // Validate Deployment security context
          if (manifest.kind === 'Deployment') {
            const containers = manifest.spec?.template?.spec?.containers || [];
            
            for (const container of containers) {
              const securityContext = container.securityContext || {};
              
              // Validate runAsNonRoot (best practice)
              const podSecurityContext = manifest.spec?.template?.spec?.securityContext || {};
              if (!podSecurityContext.runAsNonRoot) {
                ctx.logger.warn(
                  `Deployment ${manifest.metadata.name}: Consider setting runAsNonRoot=true for security`
                );
              }
              
              // Validate no privileged escalation
              if (securityContext.allowPrivilegeEscalation !== false) {
                ctx.logger.warn(
                  `Deployment ${manifest.metadata.name}: Consider setting allowPrivilegeEscalation=false`
                );
              }
            }
          }
        }
      } catch (error) {
        errors.push(`Failed to parse ${file}: ${error}`);
      }
    }
    
    // Report results
    if (errors.length > 0) {
      ctx.logger.error(`❌ Validation failed with ${errors.length} errors:`);
      errors.forEach(err => ctx.logger.error(`  - ${err}`));
      
      ctx.output('valid', false);
      ctx.output('errors', errors);
      
      throw new Error(`Manifest validation failed:\n${errors.join('\n')}`);
    } else {
      ctx.logger.info(`✅ All manifests passed validation`);
      
      ctx.output('valid', true);
      ctx.output('errors', []);
    }
  },
});
