using UnityEngine;
using System;
using System.Collections.Generic;
using System.Collections;

namespace BGM
{

    public class BgmManager : MonoBehaviour
    {
        [Header("Audio Settings")]
        [Tooltip("Default will be index 0")]
        public AudioSource[] sources;
        
        public float timeToFade=5f;
        private int _currentAudioIndex=0;
        void Awake()
        {
            if (sources == null || sources[0] == null) return;
            foreach(var s in sources)
            {
                
                s.playOnAwake = false;
                s.loop = true;
            }

            sources[_currentAudioIndex].Play();
        }
        public void PlayNextSong(float time)
        {
            int index=_currentAudioIndex+1;
            if(index>sources.Length)return;
            StopAllCoroutines();
            StartCoroutine(ChangeSong(sources[_currentAudioIndex],sources[index],timeToFade));
            _currentAudioIndex=index;
        }
        private IEnumerator ChangeSong(AudioSource currentSource, AudioSource nextSoruce, float duration)
        {
            float time = 0f;
            
            float currentSourceVolume = currentSource.volume;
            while (time < duration)
            {
                time += Time.deltaTime;
                float elapsed = time / duration;
                currentSource.volume = Mathf.Lerp(currentSourceVolume, 0, elapsed);
                yield return null;
            }
            if (currentSource.isPlaying)
            {
                
                currentSource.Stop();
                currentSource.volume=currentSourceVolume;
            }
            if (!nextSoruce.isPlaying) 
            { 
                nextSoruce.Play();
            }
            
        }

    }

}
