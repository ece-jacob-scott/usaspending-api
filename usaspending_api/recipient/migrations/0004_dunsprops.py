# -*- coding: utf-8 -*-
# Generated by Django 1.11.4 on 2018-07-19 16:03
from __future__ import unicode_literals

from django.db import migrations, models
from django.contrib.postgres.fields import ArrayField


class Migration(migrations.Migration):

    dependencies = [
        ('recipient', '0003_historicparentduns'),
    ]

    operations = [
        migrations.AddField(
            model_name='duns',
            name='address_line_1',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='address_line_2',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='city',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='congressional_district',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='country_code',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='state',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='zip',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='zip4',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='duns',
            name='business_types_codes',
            field=ArrayField(base_field=models.TextField(), default=list, size=None),
        ),
        migrations.AlterField(
            model_name='duns',
            name='legal_business_name',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='duns',
            name='ultimate_parent_legal_enti',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AlterField(
            model_name='duns',
            name='ultimate_parent_unique_ide',
            field=models.TextField(blank=True, null=True),
        ),

    ]
