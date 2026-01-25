/**
 * Custom Scaffolder Action: Generate Kubernetes Manifests
 * 
 * This action takes form input and renders Handlebars templates to generate
 * Kubernetes manifests for app deployment.
 */

import { createTemplateAction } from '@backstage/plugin-scaffolder-node';
import { z } from 'zod';
import Handlebars from 'handlebars';
import * as fs from 'fs/promises';
import * as path from 'path';

// Input schema validation
const inputSchema = z.object({
  appName: z.string().regex(/^[a-z0-9]([-a-z0-9]*[a-z0-9])?$/, 'Invalid Kubernetes name'),
  containerImage: z.string(),
  namespace: z.string().default(''),
  storagePattern: z.enum(['ephemeral', 'longhorn-persistent', 'nas-mount', 's3-external']),
  storageSize: z.string().optional(),
  nasEndpoint: z.string().optional(),
  nasSubpath: z.string().optional(),
  s3Bucket: z.string().optional(),
  ingressPattern: z.enum(['internal-only', 'external-via-tunnel']),
  backupStrategy: z.enum(['none', 'volsync-snapshots']),
  retentionDays: z.number().default(30),
  operatorId: z.string(),
});

type ManifestInput = z.infer<typeof inputSchema>;

export const generateManifestsAction = createTemplateAction<{
  appName: string;
  containerImage: string;
  namespace?: string;
  storagePattern: string;
  storageSize?: string;
  nasEndpoint?: string;
  nasSubpath?: string;
  s3Bucket?: string;
  ingressPattern: string;
  backupStrategy: string;
  retentionDays?: number;
  operatorId: string;
}>({
  id: 'custom:generate-manifests',
  description: 'Generate Kubernetes manifests from Handlebars templates',
  schema: {
    input: {
      type: 'object',
      required: ['appName', 'containerImage', 'storagePattern', 'ingressPattern', 'backupStrategy', 'operatorId'],
      properties: {
        appName: { type: 'string', description: 'Kubernetes-compatible app name' },
        containerImage: { type: 'string', description: 'Container image URL' },
        namespace: { type: 'string', description: 'Target namespace' },
        storagePattern: { type: 'string', enum: ['ephemeral', 'longhorn-persistent', 'nas-mount', 's3-external'] },
        storageSize: { type: 'string', description: 'Storage size in GB' },
        nasEndpoint: { type: 'string', description: 'NAS endpoint URL' },
        nasSubpath: { type: 'string', description: 'NAS subpath' },
        s3Bucket: { type: 'string', description: 'S3 bucket name' },
        ingressPattern: { type: 'string', enum: ['internal-only', 'external-via-tunnel'] },
        backupStrategy: { type: 'string', enum: ['none', 'volsync-snapshots'] },
        retentionDays: { type: 'number', description: 'Backup retention days' },
        operatorId: { type: 'string', description: 'Operator user ID' },
      },
    },
    output: {
      type: 'object',
      properties: {
        manifestsPath: { type: 'string', description: 'Path to generated manifests' },
        files: { type: 'array', description: 'List of generated files' },
        manifestsList: { type: 'string', description: 'Markdown list of manifests' },
      },
    },
  },
  
  async handler(ctx) {
    const input = inputSchema.parse(ctx.input);
    
    ctx.logger.info(`Generating manifests for app: ${input.appName}`);
    
    // Resolve namespace
    const namespace = input.namespace || input.appName;
    
    // Prepare template context
    const context = {
      appName: input.appName,
      containerImage: input.containerImage,
      namespace: namespace,
      operatorId: input.operatorId,
      
      // Storage flags
      hasVolume: input.storagePattern !== 'ephemeral',
      ephemeralStorage: input.storagePattern === 'ephemeral',
      longhornStorage: input.storagePattern === 'longhorn-persistent',
      nfsStorage: input.storagePattern === 'nas-mount',
      s3Enabled: input.storagePattern === 's3-external',
      
      // Storage config
      storageSize: input.storageSize || '10',
      nasServer: input.nasEndpoint?.replace('nfs://', '').split(':')[0],
      nasSubpath: input.nasSubpath,
      s3Bucket: input.s3Bucket,
      s3Region: 'us-east-1', // TODO: Make configurable
      
      // Ingress flags
      externalIngress: input.ingressPattern === 'external-via-tunnel',
      
      // Backup flags
      volsyncBackup: input.backupStrategy === 'volsync-snapshots',
      retentionDays: input.retentionDays,
    };
    
    // Load templates
    const templatesDir = path.join(__dirname, '../../scaffolder-templates/gitops-app-template/skeleton');
    const outputDir = path.join(ctx.workspacePath, 'kubernetes/clusters/homelab/apps', namespace);
    await fs.mkdir(outputDir, { recursive: true });
    
    const files: string[] = [];
    const manifestsList: string[] = [];
    
    // Always generate: Deployment, Service, Ingress
    const baseTemplates = ['deployment.yaml.hbs', 'service.yaml.hbs', 'ingress.yaml.hbs'];
    
    for (const templateFile of baseTemplates) {
      const templatePath = path.join(templatesDir, templateFile);
      const templateContent = await fs.readFile(templatePath, 'utf-8');
      const template = Handlebars.compile(templateContent);
      const rendered = template(context);
      
      const outputFile = path.join(outputDir, templateFile.replace('.hbs', ''));
      await fs.writeFile(outputFile, rendered);
      
      files.push(outputFile);
      manifestsList.push(`- ${path.basename(outputFile)}`);
      ctx.logger.info(`Generated: ${path.basename(outputFile)}`);
    }
    
    // Conditional: Storage
    if (input.storagePattern === 'longhorn-persistent') {
      const templatePath = path.join(templatesDir, 'pvc-longhorn.yaml.hbs');
      const templateContent = await fs.readFile(templatePath, 'utf-8');
      const template = Handlebars.compile(templateContent);
      const rendered = template(context);
      
      const outputFile = path.join(outputDir, 'pvc-longhorn.yaml');
      await fs.writeFile(outputFile, rendered);
      
      files.push(outputFile);
      manifestsList.push(`- pvc-longhorn.yaml`);
      ctx.logger.info(`Generated: pvc-longhorn.yaml`);
    }
    
    if (input.storagePattern === 'nas-mount') {
      const templatePath = path.join(templatesDir, 'pvc-nfs.yaml.hbs');
      const templateContent = await fs.readFile(templatePath, 'utf-8');
      const template = Handlebars.compile(templateContent);
      const rendered = template(context);
      
      const outputFile = path.join(outputDir, 'pvc-nfs.yaml');
      await fs.writeFile(outputFile, rendered);
      
      files.push(outputFile);
      manifestsList.push(`- pvc-nfs.yaml`);
      ctx.logger.info(`Generated: pvc-nfs.yaml`);
    }
    
    // Conditional: Backup
    if (input.backupStrategy === 'volsync-snapshots') {
      const templatePath = path.join(templatesDir, 'volsync.yaml.hbs');
      const templateContent = await fs.readFile(templatePath, 'utf-8');
      const template = Handlebars.compile(templateContent);
      const rendered = template(context);
      
      const outputFile = path.join(outputDir, 'volsync.yaml');
      await fs.writeFile(outputFile, rendered);
      
      files.push(outputFile);
      manifestsList.push(`- volsync.yaml`);
      ctx.logger.info(`Generated: volsync.yaml`);
    }
    
    // Generate kustomization.yaml
    const kustomizationTemplate = path.join(templatesDir, 'kustomization.yaml.hbs');
    const kustomizationContent = await fs.readFile(kustomizationTemplate, 'utf-8');
    const template = Handlebars.compile(kustomizationContent);
    const rendered = template(context);
    
    const kustomizationFile = path.join(outputDir, 'kustomization.yaml');
    await fs.writeFile(kustomizationFile, rendered);
    
    files.push(kustomizationFile);
    manifestsList.push(`- kustomization.yaml`);
    ctx.logger.info(`Generated: kustomization.yaml`);
    
    // Return output
    ctx.output('manifestsPath', outputDir);
    ctx.output('files', files);
    ctx.output('manifestsList', manifestsList.join('\n'));
    
    ctx.logger.info(`✅ Generated ${files.length} manifest files`);
  },
});
