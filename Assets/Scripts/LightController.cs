    using System.Collections;
    using UnityEngine;
    using UnityEngine.Experimental.GlobalIllumination;
using UnityEngine.Rendering;

public class LightController : MonoBehaviour
    {
        public Light directionalLight=null;

        public Light alarmLight;

        public Volume alarmPostprocessing;
        public float intervalTime=1f;
    
        private float _alarmLightInitalIntensity;
        private float _alarmVolumeInitalIntensity;
    
    
        private const int ALARM_LIGHT_BlINKS=10;

    private void Awake()
    {
        if (alarmLight == null)
        {
            alarmLight = GameObject.Find("Alarm Light")
                .GetComponent<Light>();
        }
        if (directionalLight == null)
        {
            directionalLight = GameObject.Find("Directional Light")
                .GetComponent<Light>();
        }
        if (alarmPostprocessing == null)
        {
            alarmPostprocessing = GameObject.Find("PostProcesingBloom")
                .GetComponent<Volume>();
        }
        if (alarmLight != null)
        {
            _alarmLightInitalIntensity = alarmLight.intensity;
            alarmLight.enabled = false;
        }
        if (alarmPostprocessing != null)
        {
            alarmPostprocessing.enabled = false;
        }

        }

        public void StartLightCouroutine()
        {
            StartCoroutine(StartDangerSequence());
        }
        private IEnumerator StartDangerSequence()
        {

            if (!directionalLight || 
                    !alarmLight || 
                    !alarmPostprocessing) yield break;
            
            directionalLight.intensity = 0;
            alarmLight.enabled = true;
            for(int i = 0; i <= ALARM_LIGHT_BlINKS; i++)
            {
                alarmPostprocessing.enabled = true;
                alarmLight.intensity = _alarmLightInitalIntensity;
                    
                yield return new WaitForSeconds(intervalTime);
                alarmPostprocessing.enabled = false;
                alarmLight.intensity = 0;
                yield return new WaitForSeconds(intervalTime);
            }
        }
    }
